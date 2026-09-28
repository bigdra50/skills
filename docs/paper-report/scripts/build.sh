#!/usr/bin/env bash
# Build a paper-report .tex with Tectonic, check the log, and render the pages for review.
#
#   build.sh <file.tex> [pages-dir]
#
# Prints a one-line summary per check. Exit status is non-zero when the build fails,
# the log has overfull boxes, missing glyphs, or undefined references, or the source has
# sentences inside table cells or text smaller than 7 pt (check_source.py).
# Pages are written to <pages-dir>/p-NN.png, and <pages-dir>/sheet.png holds all pages side by side.
set -euo pipefail

tex=${1:?usage: build.sh <file.tex> [pages-dir]}
# Resolve this script's directory before the cd below, so a relative invocation still finds check_source.py
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dir=$(cd "$(dirname "$tex")" && pwd)
base=$(basename "$tex" .tex)
pages=${2:-"${TMPDIR:-/tmp}/paper-report-${base}"}
cd "$dir"

# Tectonic downloads packages and fonts on first use. A dropped connection shows up as
# "font ... cannot be found", so retry once before treating it as a real error.
build() { tectonic -X compile --keep-logs "$base.tex" >"$pages.build.out" 2>&1; }
mkdir -p "$(dirname "$pages")"
if ! build; then
  if grep -q 'failed to download\|dns error' "$pages.build.out"; then
    echo "network error while fetching the bundle; retrying once"
    build || { grep -n '^error' "$pages.build.out" | head -20; exit 1; }
  else
    grep -n '^error' "$pages.build.out" | head -20
    exit 1
  fi
fi

log="$base.log"
overfull=$(grep -c 'Overfull \\hbox' "$log" || true)
missing=$(grep -c 'Missing character' "$log" || true)
undefined=$(grep -Ec "Reference .* undefined|Citation .* undefined" "$log" || true)
echo "build: ok ($base.pdf)"
echo "overfull boxes: $overfull"
echo "missing characters: $missing"
echo "undefined references: $undefined"
if [ "$overfull" -gt 0 ]; then grep -A1 'Overfull \\hbox' "$log" | head -20; fi
if [ "$missing" -gt 0 ]; then grep 'Missing character' "$log" | sort | uniq -c | head -20; fi
rm -f "$log"

# Figure and table rules that can be read off the source (references/figures.md, Style)
read -r sentences small <<<"$(python3 "$here/check_source.py" "$base.tex")"
echo "sentences in table cells: $sentences"
echo "text below 7 pt: $small"

if command -v pdftoppm >/dev/null; then
  rm -rf "$pages" && mkdir -p "$pages"
  pdftoppm -r 45 -png "$base.pdf" "$pages/p"
  echo "pages: $(ls "$pages" | wc -l | tr -d ' ') -> $pages"
  python3 - "$pages" <<'PY' || echo "contact sheet skipped (needs Pillow)"
import glob, sys
from PIL import Image
d = sys.argv[1]
ims = [Image.open(f) for f in sorted(glob.glob(f"{d}/p-*.png"))]
w, h = ims[0].size
cols = 6
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (w + 6), rows * (h + 6)), (120, 120, 120))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * (w + 6), (i // cols) * (h + 6)))
sheet.save(f"{d}/sheet.png")
print(f"sheet: {d}/sheet.png")
PY
else
  echo "pdftoppm not found; open the PDF and check the pages by eye"
fi

[ "$overfull" -eq 0 ] && [ "$missing" -eq 0 ] && [ "$undefined" -eq 0 ] \
  && [ "$sentences" -eq 0 ] && [ "$small" -eq 0 ]
