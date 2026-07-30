---
name: disk-usage
description: |
  ディスク使用量の調査・分析・クリーンアップ支援。mise run disk-usage を活用してレポート取得し、結果を分析して削除候補を提示する。
  Use for: "ディスク容量", "容量確認", "ディスク不足", "空き容量", "クリーンアップ", "キャッシュ削除", "disk usage", "disk full"
allowed-tools: Bash, Read, Glob
user-invocable: true
---

# Disk Usage Analyzer

`mise run disk-usage` を使ってディスク使用量を調査し、削除候補を分析・提示する。

## 利用可能コマンド

```bash
mise run disk-usage              # 全カテゴリのフルレポート
mise run disk-usage summary      # ディスク概要 + Top 10
mise run disk-usage clean        # 安全な削除コマンド一覧 (dry-run)
mise run disk-usage breakdown            # 全カテゴリ内訳
mise run disk-usage breakdown docker     # Docker images/volumes
mise run disk-usage breakdown xcode      # DerivedData/DeviceSupport/Archives
mise run disk-usage breakdown unity      # Editor versions/caches
mise run disk-usage breakdown runtimes   # mise/asdf/dotnet/rustup
```

## ワークフロー

1. `mise run disk-usage summary` で概況把握
2. 大きいカテゴリを `breakdown` で深掘り
3. `mise run disk-usage clean` で安全な削除候補を取得
4. 結果を分析し、Tier分けした削除候補テーブルを提示

## 削除候補の提示ルール

- Tier 1: キャッシュ（再取得可能）
- Tier 2: 旧バージョン・インストール済みアーカイブ
- Tier 3: Docker関連
- Tier 4: 要判断（現行利用中の可能性あり）

各候補に サイズ と 削除コマンド を明記する。clean サブコマンドの出力はdry-runであり、実際の削除はユーザー承認後に行う。

## 注意事項

- 削除実行前に必ずユーザーの明示的な承認を得る
- `clean` が出力するコマンドは実行されない（echo のみ）
- フルレポートは時間がかかるため、まず `summary` から始める
- `/usr/bin/du` を使用（dust aliasを回避済み）
- `/bin/df` を使用（duf aliasを回避）
