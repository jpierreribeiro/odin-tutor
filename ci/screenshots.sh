#!/bin/sh
# Regenerate the README's screenshots FROM THE RUNNING TOOL.
#
#   ./ci/screenshots.sh
#
# Nothing here is typed by hand. A screenshot that drifts from what the tool
# prints is worse than no screenshot, because it is the first thing a reader
# believes — and this project shipped a README block for weeks showing a label
# format the renderer had stopped producing.
#
# SVG and PNG from the same captured text: GitHub renders the SVG, and link
# previews on social sites need a raster. Two files, one source, so they cannot
# disagree.
#
# ASCII rather than Unicode, on purpose. `②` and `→` are decoration that
# SPEC-TUI-041 guarantees loses nothing when removed, and NO monospace font on a
# normal Linux box has the circled digits — they render as empty boxes, which is
# a worse picture than the plain form the tool prints by default.
set -e

: "${ODIN_ROOT:?set ODIN_ROOT to your Odin checkout}"
export PATH="$ODIN_ROOT:$PATH"
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

odin build src/tutor -out:"$work/odin-tutor" >/dev/null
tool="$work/odin-tutor"
# The tool finds its adapter beside its own executable, and this one was built
# into a scratch directory. Naming it is what an installed layout does for free.
export TUTOR_ADAPTER="$root/adapter/gdb_extractor.py"
export TUTOR_EXERCISES="$root/exercises"

shot() {  # shot <captured text> <title> <basename>
	python3 ci/terminal-to-svg.py "$1" "$2" "docs/images/$3.svg"
	python3 ci/terminal-to-png.py "$1" "$2" "docs/images/$3.png"
}

strip_ansi() {
	sed 's/\r$//' | sed 's/\x1b\[[?0-9;]*[a-zA-Z]//g'
}

# ---------------------------------------------------------------------------
# A course, standing in front of the flagship exercise with the twelve before
# it done, so the progress bar shows a course in progress rather than an empty
# one.
"$tool" init "$work/course" >/dev/null
python3 - "$work/course" <<'SCRIPT'
import json, pathlib, sys
course = pathlib.Path(sys.argv[1])
done = [d.name for d in sorted((course / "exercises").iterdir()) if d.name < "13-sub-slices"]
(course / ".odin-tutor" / "progress.json").write_text(
    json.dumps({"completed": done, "welcomed": True}))
# The attempt that makes the point: a copy, which prints the right answer.
(course / "exercises" / "13-sub-slices" / "start.odin").write_text('''package main

import "core:fmt"

main :: proc() {
	todos := []int{1, 2, 3}
	parte := []int{2, 3}
	fmt.println(len(todos), len(parte))
}
''')
SCRIPT

# 1. THE LOOP, failing. Driven through a pseudo-terminal, because that is the
#    only way to see the screen a student sees.
(cd "$work/course" && printf 'q' | script -qec "$tool" /dev/null) 2>&1 |
	strip_ansi |
	sed -n '/── 13-sub-slices/,/q:quit/p' |
	# The terminal echoes the keypress before the loop enters raw mode, so the
	# first line arrives with a stray `q` glued to it.
	sed '1s/^[^─]*//' > "$work/loop.txt"
shot "$work/loop.txt" "odin-tutor — the exercise loop" loop

# 2. THE PICTURE, from the reference solution, at the step where both views
#    exist. Rendered rather than driven: `render` and the interactive screen
#    share one formatter (SPEC-TUI-051), so this is the same text.
"$tool" trace exercises/13-sub-slices/solution.odin "$work/right.json" >/dev/null
steps=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['steps']))" "$work/right.json")
"$tool" render "$work/right.json" "$((steps - 1))" > "$work/picture.txt"
shot "$work/picture.txt" "odin-tutor — press t, and see the memory" picture

# 3. THE CONTRAST, which is the whole argument in one image: two programs, the
#    same printed output, and one `shares with`.
"$tool" trace exercises/13-sub-slices/wrong-copies-instead-of-sharing.odin \
	"$work/wrong.json" >/dev/null
wsteps=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['steps']))" "$work/wrong.json")
"$tool" render "$work/wrong.json" "$((wsteps - 1))" > "$work/wrongpic.txt"
python3 - "$work/picture.txt" "$work/wrongpic.txt" "$work/contrast.txt" <<'SCRIPT'
import sys

def panel(path):
    lines = open(path).read().splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith("OBJECTS"))
    end = next(i for i, l in enumerate(lines[start:], start) if l.startswith("OUTPUT"))
    return lines[start:end]

left, right = panel(sys.argv[1]), panel(sys.argv[2])
head_l, head_r = "parte := todos[1:]   A WINDOW", "parte := []int{2, 3}   A COPY"
left = [head_l, "both print `3 2`"] + [""] + left
right = [head_r, "both print `3 2`"] + [""] + right
w = max(len(l) for l in left) + 6
out = []
for i in range(max(len(left), len(right))):
    a = left[i] if i < len(left) else ""
    b = right[i] if i < len(right) else ""
    out.append((a.ljust(w) + b).rstrip())
open(sys.argv[3], "w").write("\n".join(out) + "\n")
SCRIPT
shot "$work/contrast.txt" "odin-tutor — same output, different memory" contrast

# 4. A SOLVED exercise, which waits rather than moving on (ADR-015).
cp "$work/course/exercises/13-sub-slices/solution.odin" \
	"$work/course/exercises/13-sub-slices/start.odin"
(cd "$work/course" && printf 'q' | script -qec "$tool" /dev/null) 2>&1 |
	strip_ansi |
	sed -n '/── 13-sub-slices/,/q:quit/p' |
	sed '1s/^[^─]*//' > "$work/done.txt"
shot "$work/done.txt" "odin-tutor — a solved exercise waits for you" done

# 5. THE COURSE, so the size of it is visible.
(cd "$work/course" && "$tool" list) | sed -n '1,12p' > "$work/list.txt"
printf '  ...\n' >> "$work/list.txt"
(cd "$work/course" && "$tool" list) | tail -3 >> "$work/list.txt"
shot "$work/list.txt" "odin-tutor list" list

echo
echo "regenerated from a real run"
