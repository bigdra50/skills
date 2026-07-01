#!/usr/bin/env node
// Even Hub への build アップロード自動化 (Web UI の「Upload a build → Add build」相当)。
// 公式 evenhub CLI に upload コマンドが無いため、Web UI が使う API を呼ぶ:
//   1) POST /api/v1/versions/draft?package_id=<pkg>   FormData{ehpk:file}            → draft_id
//   2) POST /api/v1/versions/create?package_id=<pkg>  FormData{draft_id,changelog}   → build を Private で追加
// ② create は Web UI の「Add build」ボタン相当。追加されるビルドは Private。
// 公開 (Private→Public 切替) は別 API で、本スクリプトでは扱わない (実行しない)。
// 認証: ~/.config/evenhub/credentials.yaml の access_token を X-Even-Authorization ヘッダに載せる
//   (evenhub login で取得・保存。Bearer 接頭辞なし)。失効 (10分) 時は refresh_token で自動更新。
//
// プロジェクトルート (app.json と pack 済み .ehpk がある場所) で実行する:
//   node <このファイル> -m "changelog"   # draft → create (= Add build, Private 追加)
//   node <このファイル> --draft-only      # draft のみ (検証用。ビルドは追加しない)
//   オプション: --file <ehpk> --package <id> -m/--changelog <text(最大500字)>
// app.json の package_id と cwd の *.ehpk を自動検出するため、プロジェクト固有の編集は不要。

import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'

const BASE = process.env.EVENHUB_API_URL || 'https://hub.evenrealities.com'
const CRED = join(process.env.XDG_CONFIG_HOME || join(homedir(), '.config'), 'evenhub', 'credentials.yaml')

function arg(...names) {
  for (const n of names) {
    const i = process.argv.indexOf(n)
    if (i >= 0) return process.argv[i + 1] ?? true
  }
  return undefined
}
function has(name) {
  return process.argv.includes(name)
}

// credentials.yaml をパースする。YAML の折りたたみブロックスカラー (`key: >-` の次行に値) と
// インライン (`key: value`) の両方に対応。evenhub login が書く形式。値は表示しない。
function readCreds() {
  let text
  try {
    text = readFileSync(CRED, 'utf8')
  } catch {
    throw new Error(`認証情報が読めません: ${CRED}\nまず自分のターミナルで \`evenhub login\` を実行してください。`)
  }
  const lines = text.split('\n')
  const out = {}
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^([a-z_]+)\s*:\s*(.*)$/)
    if (!m) continue
    const [, key, rest] = m
    const v = rest.trim()
    if (/^[>|][+-]?$/.test(v)) {
      // ブロックスカラー: 後続のインデント行を集めて連結 (token は単一トークン=空白なし結合)
      const parts = []
      for (let j = i + 1; j < lines.length; j++) {
        if (/^\s+\S/.test(lines[j])) parts.push(lines[j].trim())
        else if (lines[j].trim() === '') continue
        else break
      }
      out[key] = parts.join('')
    } else {
      out[key] = v.replace(/^["']|["']$/g, '')
    }
  }
  return out
}

// 更新トークンを credentials.yaml に書き戻す (インライン plain scalar。JWT は YAML 特殊文字を含まない)。
function writeCreds(c) {
  const order = [
    'email',
    'role',
    'access_token',
    'refresh_token',
    'access_token_expires_in',
    'refresh_token_expires_in',
  ]
  const body = order
    .filter((k) => c[k] !== undefined)
    .map((k) => `${k}: ${c[k]}`)
    .join('\n')
  writeFileSync(CRED, `${body}\n`, { mode: 0o600 })
}

// refresh_token で access_token を更新する (POST /api/v1/auth/refresh, 認証ヘッダ不要)。
async function refresh(creds) {
  const res = await fetch(`${BASE}/api/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: creds.refresh_token }),
  })
  const body = await res.json().catch(() => ({ code: -1 }))
  if (body.code !== 0 || !body.data?.access_token) {
    throw new Error('トークン更新に失敗しました。`evenhub login` を再実行してください。')
  }
  const updated = {
    ...creds,
    access_token: body.data.access_token,
    refresh_token: body.data.refresh_token ?? creds.refresh_token,
    access_token_expires_in: body.data.access_token_expires_in ?? creds.access_token_expires_in,
    refresh_token_expires_in: body.data.refresh_token_expires_in ?? creds.refresh_token_expires_in,
  }
  writeCreds(updated)
  return updated
}

// state.creds を使って POST。401 なら一度だけ refresh して再試行。form は () => FormData で都度生成。
const state = { creds: null }
async function api(path, makeForm, pkg, retried = false) {
  const url = `${BASE}${path}?package_id=${encodeURIComponent(pkg)}`
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'X-Even-Authorization': state.creds.access_token },
    body: makeForm(),
  })
  if (res.status === 401 && !retried) {
    state.creds = await refresh(state.creds)
    return api(path, makeForm, pkg, true)
  }
  let body
  try {
    body = await res.json()
  } catch {
    body = { code: -1, message: `非JSON応答 (HTTP ${res.status})` }
  }
  if (body.code !== 0) {
    throw new Error(`API エラー (HTTP ${res.status}, code ${body.code}): ${body.message ?? JSON.stringify(body)}`)
  }
  return body.data
}

// cwd の *.ehpk を検出 (--file 優先)。複数あれば最新 (mtime) を選び、その旨を明示する
// (baseline.ehpk 等の併存で誤爆しないよう。曖昧なときは --file 推奨)。
function detectEhpk() {
  const found = readdirSync('.')
    .filter((f) => f.endsWith('.ehpk'))
    .map((f) => ({ f, t: statSync(f).mtimeMs }))
    .sort((a, b) => b.t - a.t)
  if (found.length === 0) {
    throw new Error('カレントに .ehpk が見つかりません。まず pack してください (例: npm run pack)。')
  }
  if (found.length > 1) {
    console.log(
      `注意: .ehpk が複数あります。最新を使用: ${found[0].f} (他: ${found.slice(1).map((x) => x.f).join(', ')})。明示するには --file。`,
    )
  }
  return found[0].f
}

async function main() {
  const app = JSON.parse(readFileSync('app.json', 'utf8'))
  const pkg = arg('--package') || app.package_id
  if (!pkg) throw new Error('package_id が不明です。app.json に package_id があるか確認してください (--package で上書き可)。')
  const file = arg('--file') || detectEhpk()
  const changelog = (arg('-m', '--changelog') || '').slice(0, 500)
  const addBuild = !has('--draft-only') // 既定で Add build (create) まで。--draft-only で draft 止め
  state.creds = readCreds()

  console.log(`package : ${pkg}`)
  console.log(`file    : ${file} (app.json version ${app.version})`)
  console.log(`mode    : ${addBuild ? 'draft → create (Add build, Private 追加)' : 'draft のみ (検証)'}`)

  // 1) draft upload
  const buf = readFileSync(file)
  const name = file.split('/').pop()
  const draft = await api(
    '/api/v1/versions/draft',
    () => {
      const f = new FormData()
      f.append('ehpk', new Blob([buf], { type: 'application/octet-stream' }), name)
      return f
    },
    pkg,
  )
  const draftId = draft?.draft_id ?? draft?.id ?? draft?.draftId
  console.log(`✓ draft uploaded: draft_id=${draftId}`)
  if (!draftId) {
    console.log('draft 応答にdraft_idが見当たりません。応答全体:', JSON.stringify(draft))
    throw new Error('draft_id を取得できませんでした (応答フィールド名を確認してください)')
  }

  if (!addBuild) {
    console.log('\ndraft のみ完了 (ビルドは追加していません)。Add build するには --draft-only を外して再実行してください。')
    return
  }

  // 2) create (= Add build。Private で追加。公開ではない)
  const created = await api(
    '/api/v1/versions/create',
    () => {
      const f = new FormData()
      f.append('draft_id', String(draftId))
      if (changelog) f.append('changelog', changelog)
      return f
    },
    pkg,
  )
  console.log(`✓ Add build 完了 (Private で追加): ${JSON.stringify(created)}`)
  console.log('公開する場合はハブの UI で Private→Public を切り替えてください (本スクリプトは行いません)。')
}

main().catch((e) => {
  console.error(`✗ ${e.message}`)
  process.exit(1)
})
