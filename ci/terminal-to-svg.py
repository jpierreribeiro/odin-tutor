"""Render captured terminal text as an SVG, for the README.

The text is CAPTURED, never typed by hand: a screenshot that drifts from what
the tool prints is worse than no screenshot, because it is the first thing a
reader believes. Regenerate with `make-screenshots.sh`.
"""
import sys, html

CW, LH, PAD, TOP = 8.4, 20, 20, 42
FG, DIM, BG, ACCENT, WARN, OK = "#d8dee9", "#7a8496", "#191d24", "#88c0d0", "#e8a33d", "#a3be8c"

def colour(line):
    s = line.strip()
    if s.startswith("FAIL"):                      return WARN
    if s.startswith("pass"):                      return OK
    if s.startswith(("FRAMES", "OBJECTS", "CODE", "OUTPUT SO FAR", "STEP")): return ACCENT
    if s.startswith("──"):                        return ACCENT
    if "shares with" in line:                     return OK
    if s.startswith(("Progress:", "Current exercise:")): return DIM
    if "h:hint" in line or "<- ->" in line:       return DIM
    if s.startswith("Press `t`"):                 return WARN
    return FG

def render(path, title, out):
    lines = [l.rstrip("\n") for l in open(path, encoding="utf-8")]
    while lines and not lines[-1].strip(): lines.pop()
    width = max(len(l) for l in lines) + 4
    w, h = int(width * CW + PAD * 2), int(len(lines) * LH + TOP + PAD)
    p = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="ui-monospace,SFMono-Regular,Menlo,Consolas,monospace" font-size="13">']
    p.append(f'<rect width="{w}" height="{h}" rx="8" fill="{BG}"/>')
    for i, (c, x) in enumerate([("#e06c62", 20), ("#e0b562", 40), ("#8fbf72", 60)]):
        p.append(f'<circle cx="{x}" cy="21" r="6" fill="{c}"/>')
    p.append(f'<text x="{w/2}" y="26" fill="{DIM}" text-anchor="middle" font-size="12">{html.escape(title)}</text>')
    for i, line in enumerate(lines):
        y = TOP + i * LH
        p.append(f'<text x="{PAD}" y="{y}" fill="{colour(line)}" xml:space="preserve">{html.escape(line)}</text>')
    p.append("</svg>")
    open(out, "w", encoding="utf-8").write("\n".join(p))
    print(f"{out}  {w}x{h}  {len(lines)} lines")

render(sys.argv[1], sys.argv[2], sys.argv[3])
