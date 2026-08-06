"""Render captured terminal text as a PNG, for the README and for sharing.

Why a PNG as well as an SVG: GitHub renders the SVG, and link previews on
social sites do not — they need a raster image. Both are generated from the
SAME captured text by ci/screenshots.sh, so they cannot disagree with each
other or with the tool.

Drawn at 2x and downsampled, because a terminal screenshot is read at its own
size and thin glyphs like `│` fall apart without it.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

SCALE = 2
SIZE = 15
PAD, TOP, LH = 22, 46, 22
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

FG, DIM, BG, CHROME = "#d8dee9", "#7a8496", "#191d24", "#11141a"
ACCENT, WARN, OK = "#88c0d0", "#e8a33d", "#a3be8c"


def colour(line):
    s = line.strip()
    if s.startswith("FAIL"):
        return WARN
    if s.startswith("pass"):
        return OK
    if s.startswith(("FRAMES", "OBJECTS", "CODE", "OUTPUT SO FAR", "STEP", "LIMITS", "GIVEN BACK")):
        return ACCENT
    if s.startswith("──") or s.startswith("Exercise done"):
        return ACCENT
    if "shares with" in line:
        return OK
    if s.startswith(("Progress:", "Current exercise:", "Solution for comparison:")):
        return DIM
    if "h:hint" in line or "<- ->" in line or "n:next" in line:
        return DIM
    if s.startswith(("Press `t`", "When done experimenting")):
        return WARN
    return FG


def render(source, title, out):
    lines = [l.rstrip("\n") for l in open(source, encoding="utf-8")]
    while lines and not lines[-1].strip():
        lines.pop()

    font = ImageFont.truetype(FONT, SIZE * SCALE)
    small = ImageFont.truetype(FONT, int(SIZE * 0.85) * SCALE)
    cw = font.getlength("M")
    width = int(max(len(l) for l in lines) * cw) + PAD * 2 * SCALE
    height = len(lines) * LH * SCALE + (TOP + PAD) * SCALE

    image = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(image)
    d.rectangle([0, 0, width, TOP * SCALE - 8], fill=CHROME)
    for i, c in enumerate(("#e06c62", "#e0b562", "#8fbf72")):
        x = (20 + i * 20) * SCALE
        r = 6 * SCALE
        d.ellipse([x - r, 16 * SCALE - r, x + r, 16 * SCALE + r], fill=c)
    d.text((width / 2, 16 * SCALE), title, font=small, fill=DIM, anchor="mm")

    for i, line in enumerate(lines):
        d.text((PAD * SCALE, (TOP + i * LH) * SCALE), line, font=font, fill=colour(line))

    image.resize((width // SCALE, height // SCALE), Image.LANCZOS).save(out)
    print("%s  %dx%d  %d lines" % (out, width // SCALE, height // SCALE, len(lines)))


render(sys.argv[1], sys.argv[2], sys.argv[3])
