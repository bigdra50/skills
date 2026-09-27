# LaTeX pitfalls

Each entry is a failure seen while building a report with the template, and its fix.

## Class and fonts

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Option clash for package geometry` | `bxjsarticle` loads geometry itself | Use `\geometry{...}` instead of `\usepackage[...]{geometry}` |
| `Missing \begin{document}` at the Japanese font line | `\setjamainfont` takes options before the name | `\setjamainfont[BoldFont=HiraMinProN-W6]{HiraMinProN-W3}` |
| `The font "SourceSerifPro-It" cannot be found` | The TeX Live file names differ from Adobe's | Italics are `*-RegularIt` and `*-SemiboldIt`. Probe a name with a one-line document before using it |
| `font ... cannot be found` together with `dns error` | Tectonic fetches fonts on first use and the network dropped | Retry the build; `scripts/build.sh` retries once |
| Japanese characters missing inside `\code{}` | url-based commands bypass the Japanese font switch | Keep `\code{}` to ASCII; write Japanese outside it |
| No Hiragino outside macOS | The Japanese fonts come from the OS | Swap the two `\setja...font` lines for installed fonts (for example Noto Serif CJK JP and Noto Sans CJK JP) |

Font families that load from the Tectonic bundle:

- Source: `SourceSerifPro-*`, `SourceSansPro-*`, `SourceCodePro-*` (`SourceSerif4` and `SourceSans3` are not in the bundle)
- STIX Two: `STIXTwoText-*`, `STIXTwoMath-Regular.otf`
- Libertinus: `LibertinusSerif-*`, `LibertinusSans-*`, `LibertinusMath-Regular.otf`
- IBM Plex: `IBMPlexSerif-*`, `IBMPlexSans-*`, `IBMPlexMono-*`
- Fira: `FiraSans-*`, `FiraMono-*`
- TeX Gyre: `texgyretermes-*`, `texgyreheros-*`

## Macros

| Symptom | Cause | Fix |
| --- | --- | --- |
| `\url used in a moving argument` in a caption | `\DeclareUrlCommand` commands are fragile | Declare `\codeurl` with `\DeclareUrlCommand` and wrap it: `\DeclareRobustCommand{\code}{\codeurl}` |
| Long identifiers push past the column | Monospace words cannot hyphenate | Load `xurl` so `\code{}` breaks at `/`, `_`, and between letters |
| `%` or `#` breaks `\code{}` | url commands cannot take them in arguments | Write them with `\texttt{\%}` or rephrase |

## Layout

| Symptom | Cause | Fix |
| --- | --- | --- |
| Overfull box at a TikZ picture or pgfplots axis | Picture wider than the column | pgfplots `width=0.93\columnwidth`; for physical drawings, shrink the meters-to-cm scale |
| A narrow table column squeezes the others | `l` columns size to their longest cell | Give long first or last columns fixed `p{..mm}` widths and let `X` columns share the rest |
| A title-block line leaves one word on the next line | Two items joined with `\qquad` | Break with `\\` instead |
| Wide figures all land at page tops | `figure*` in two-column mode only floats to the top of a later page | Expected; place the `figure*` source a little before the text that references it |

## Drawing order in TikZ

A box filled with white hides anything drawn before it.
Draw translucent overlays (a field-of-view wedge, a highlight) after the boxes they cross, with `fill opacity`.

## Checking

- The log is the ground truth for overfull boxes, missing glyphs, and undefined references. `scripts/build.sh` counts all three
- Look at every figure page at a readable zoom, not only the contact sheet. Label collisions and hidden overlays do not show in the log
- `pdftoppm -r 110 -f N -l N file.pdf out` renders a single page for a close look
- ImageMagick `montage` needs a font configured to label tiles; the script builds the contact sheet with Pillow instead
