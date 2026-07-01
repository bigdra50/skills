---
name: kb-macos
description: macOS固有のCLIテクニック。osascript、pbcopy/pbpaste、ImageMagick、sips等
user-invocable: true
---

# macOS CLIナレッジ

macOS固有のコマンドやツールに関する学びを記録する。

## クリップボード

### 画像をファイルに保存

`pbpaste`はテキスト専用。画像は`osascript`で保存する。

```bash
osascript \
  -e 'set imgData to the clipboard as <<class PNGf>>' \
  -e 'set filePath to POSIX file "/path/to/output.png"' \
  -e 'set fileRef to open for access filePath with write permission' \
  -e 'write imgData to fileRef' \
  -e 'close access fileRef'
```

---

## 画像操作

### 複数画像を横並びに結合（ImageMagick）

```bash
# 単純な横並び結合
magick a.png b.png c.png +append output.png

# 画像間にスペースを挿入（最後以外の各画像の右に8px追加）
magick \
  \( a.png -bordercolor '#E8E8EC' -gravity east -splice 8x0 \) \
  \( b.png -bordercolor '#E8E8EC' -gravity east -splice 8x0 \) \
  c.png +append output.png
```

- `+append`: 横並び / `-append`: 縦並び
- `-splice WxH`: 指定方向にスペースを挿入

### 画像サイズ確認（sips）

```bash
sips -g pixelWidth -g pixelHeight file.png
```

`sips`はmacOS標準。ImageMagickの`identify`と同等だがインストール不要。

---

## osascript

<!-- AppleScript/JXA経由のmacOS操作 -->

---

## ネットワーク

### LocalHostName と mDNS (.local)

macOS は Bonjour (mDNS) で `{LocalHostName}.local` というアドレスを自動公開する。同一 LAN 内の機器から IP アドレスを知らなくてもアクセスできる。

```bash
# ホスト名の確認
scutil --get LocalHostName

# 使用例: LAN内の別デバイスからアクセス
curl http://MyMac.local:8080/ping
```

DHCP で IP が変わっても `.local` アドレスは維持される。iOS デバイスからも参照可能。ローカルサーバーの URL を固定したい場合に有用。

---

## Homebrew/CLI

<!-- Homebrew、macOS固有のCLIツール -->

---
