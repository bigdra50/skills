#!/usr/bin/env bash
# docs-architect 回帰テスト用 fixture 生成スクリプト
# 使い方: bash setup-fixtures.sh [BASE_DIR]
# 注意: /tmp はサンドボックスのセッション毎に分離されるため、永続パス (~/.cache) を既定にする
set -euo pipefail

BASE="${1:-$HOME/.cache/docs-arch-eval}"
rm -rf "$BASE/fixture-b-cli" "$BASE/fixture-c-messy"
mkdir -p "$BASE/fixture-b-cli/src/logsift" "$BASE/fixture-b-cli/tests" \
         "$BASE/fixture-c-messy/src/reqtrack" "$BASE/fixture-c-messy/docs"

# ---- fixture B: docs ゼロの新規 Python CLI (init モード用) ----
cd "$BASE/fixture-b-cli"
cat > pyproject.toml <<'EOF'
[project]
name = "logsift"
version = "0.1.0"
description = "Filter and aggregate structured log files from the command line"
requires-python = ">=3.10"
dependencies = []

[project.scripts]
logsift = "logsift.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
EOF
printf '__version__ = "0.1.0"\n' > src/logsift/__init__.py
cat > src/logsift/cli.py <<'EOF'
import argparse
import json
import sys


def main() -> int:
    p = argparse.ArgumentParser(prog="logsift", description="Filter structured logs")
    p.add_argument("file", help="JSONL log file (- for stdin)")
    p.add_argument("--level", default=None, help="filter by level (info/warn/error)")
    p.add_argument("--count", action="store_true", help="print only the match count")
    args = p.parse_args()
    src = sys.stdin if args.file == "-" else open(args.file)
    hits = 0
    for line in src:
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if args.level and rec.get("level") != args.level:
            continue
        hits += 1
        if not args.count:
            print(line, end="")
    if args.count:
        print(hits)
    return 0
EOF
cat > tests/test_cli.py <<'EOF'
from logsift import __version__


def test_version():
    assert __version__ == "0.1.0"
EOF
git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm "initial: logsift CLI"

# ---- fixture C: 重複・陳腐化 docs + 喪失検出マーカー 8 個 (restructure モード用) ----
cd "$BASE/fixture-c-messy"
cat > pyproject.toml <<'EOF'
[project]
name = "reqtrack"
version = "2.3.0"
description = "HTTP request tracking middleware for WSGI apps"
requires-python = ">=3.10"
EOF
cat > src/reqtrack/__init__.py <<'EOF'
__version__ = "2.3.0"


class Tracker:
    def __init__(self, app, sample_rate=1.0):
        self.app = app
        self.sample_rate = sample_rate
EOF
cat > README.md <<'EOF'
# reqtrack

HTTP request tracking middleware for WSGI apps.

## Install

```bash
pip install reqtrack
```

MARKER-C1-INSTALL-EXTRAS: GeoIP 連携を使う場合は `pip install 'reqtrack[geoip]'` を選ぶ。

## Usage

```python
from reqtrack import Tracker
app = Tracker(app, sample_rate=0.5)
```

## API

### Tracker(app, sample_rate=1.0)

MARKER-C2-API-SAMPLERATE: sample_rate は 0.0-1.0。0.3 超を本番で使うと overhead が約 8% 増える実測がある。

### Tracker.flush()

バッファされたイベントを送信する。

## 開発に参加する

MARKER-C3-DEVSETUP-REDIS: テストは Redis 7 をローカルの 6380 ポートで要求する (6379 ではない)。

```bash
pip install -e '.[dev]' && pytest
```

## リリース手順

MARKER-C4-RELEASE-TWINE: タグ push 後、twine upload は CI が行うので手動実行しないこと。

## License

MIT
EOF
cat > SETUP.md <<'EOF'
# Setup (old)

このファイルは v1 時代のセットアップ手順。

```bash
python setup.py install
```

MARKER-C5-OLD-PYENV: v1 系は Python 3.6 でしか動かない。pyenv で 3.6.15 を入れること。
EOF
cat > docs/setup.md <<'EOF'
# Setup

インストール:

```bash
pip install reqtrack
```

MARKER-C6-PROXY-ENV: 社内 proxy 配下では REQTRACK_NO_TELEMETRY=1 を設定する。
EOF
cat > docs/api.md <<'EOF'
# API リファレンス

## Tracker

MARKER-C7-TRACKER-THREADSAFE: Tracker はスレッドセーフだが fork 後は再生成が必要。

## flush()

明示 flush。README の API 節と内容が重複している。
EOF
cat > docs/old-notes.md <<'EOF'
# 2023 設計メモ (走り書き)

MARKER-C8-DESIGN-SCRATCH: いつか v3 で sampling を adaptive にしたい。誰のレビューも通っていない思いつき。
EOF
git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm "initial: reqtrack with messy docs"

echo "OK: fixtures at $BASE"
echo "  B files: $(git -C "$BASE/fixture-b-cli" ls-files | wc -l | tr -d ' ')"
echo "  C markers: $(grep -rc 'MARKER-C' "$BASE/fixture-c-messy" --include='*.md' | awk -F: '{s+=$2} END{print s}')"
