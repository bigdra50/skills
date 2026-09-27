# Figures

A figure earns its place when it shows a mechanism the reader would otherwise have to assemble from prose.
Each figure makes one claim, and its caption states that claim in the first sentence.

## What to draw

| Figure | When | How |
| --- | --- | --- |
| Overview (Figure 1) | Always | Components as boxes, data as labeled arrows, the parts this work built in the accent color, a two-entry legend |
| Primer figure | The reader is new to the domain | The core concept drawn with real names from the system (for ROS 2: a topic with one publisher and three subscribers, a service, an action) |
| Tree or hierarchy | Frames, ownership, call trees | Nodes stacked vertically, edge labels on the right saying who produces each edge and how it behaves |
| To-scale geometry | Physical layout, field of view, clearances | Coordinates in meters from the real constants, caption says "縮尺どおり" |
| Before and after | A design change fixed a problem | Two rows, the edge that changed in the warning color above and the accent color below, with the measured rate or size |
| Flow or state sequence | A multi-step procedure | Numbered boxes left to right (numbers only when order is real), failure branches below |
| Chart | Measured numbers that are compared | pgfplots, values labeled on the marks, the chosen setting marked |

Label every arrow with what moves along it (`/scan`, `速度指令 20 Hz`).
Leave the whole system out; draw the parts the argument turns on.

## Authoring wide diagrams on a pixel grid

For `figure*` diagrams, use `\begin{tikzpicture}[x=0.2mm,y=-0.2mm]`.
The y axis then grows downward like SVG, and a canvas 820 units wide is 16.4 cm, which fits the 17 cm text width.
Place boxes by their top-left corner and size, and text by its baseline:

```latex
\draw[rb] (260,140) rectangle ++(104,56);          % box
\node[tb,M] at (312,164) {odom\_fusion};            % centered bold label
\node[ts,M] at (312,182) {車輪 + ARKit};             % centered small label
\draw[arr] (312,196) -- (312,248);                  % arrow
\node[tts,S] at (318,226) {/odom, tf};              % left-aligned mono label
\node[to,M,rotate=90] at (214,271) {/wheel/odom};   % rotated label
```

Styles (`rb`, `ro`, `arr`, `M`, `S`, `E`, `t`, `ts`, `tt`, `to`, ...) are defined in the template preamble.
At this scale `\footnotesize` text is about 40 units wide per Japanese character pair; budget box widths from the longest label.
Inside TikZ node text, escape underscores as `\_` (use `\code{}` only in running text).

## Column-width drawings in physical units

For a to-scale drawing that fits one column (8.25 cm), set the axes to meters.
A top view with the robot's forward direction pointing up:

```latex
\begin{tikzpicture}[x={(0,11cm)},y={(-11cm,0)}]   % x forward = up, y left = left
\draw[rb] (-0.175,-0.225) rectangle (0.175,0.225);  % footprint 0.35 m x 0.45 m
\draw[black!45,dashed] (0,0) circle[radius=0.285];  % swept circle
\end{tikzpicture}
```

A side view: `[x=6.2cm,y=6.2cm]` with x forward and z up.
Compute ray endpoints (field-of-view edges, intersections) from the real angles and heights.
State in the caption which quantities are drawn to scale.

## Charts with pgfplots

- Width `0.93\columnwidth`; a full `\columnwidth` plus tick labels overflows the column
- Horizontal bars (`xbar`) for signed errors per run, with a zero line
  - Use `point meta=x` so `nodes near coords align=horizontal` places labels right of positive and left of negative bars. Symbolic meta values stack the labels above the bars instead
  - Later `\addplot` calls sit higher within each group. Add series bottom-up and use `reverse legend`
  - Put the first group at the largest y instead of using `y dir=reverse`
- Line charts for a swept parameter, one panel per metric (no dual axes), the chosen value marked with a dashed accent line and a label
- Number formatting: `\pgfmathprintnumber[fixed,fixed zerofill,precision=2,showpos]{\pgfplotspointmeta}`

## Raster images

Use a real image only when it is data (a map, a plot produced by the experiment).
Copy it next to the `.tex` under `fig/` so the report builds on its own.
Say what each color in it means in the caption.
