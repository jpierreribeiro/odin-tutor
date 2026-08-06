#!/bin/sh
# Regenerate the README's screenshots FROM THE RUNNING TOOL.
#
#   ./ci/screenshots.sh
#
# Nothing here is typed by hand. A screenshot that drifts from what the tool
# prints is worse than no screenshot, because it is the first thing a reader
# believes — and this project shipped a README block for weeks showing a label
# format the renderer had stopped producing.
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
# into a scratch directory. Naming it is what the installed layout does for
# free.
export TUTOR_ADAPTER="$root/adapter/gdb_extractor.py"
export TUTOR_EXERCISES="$root/exercises"

# 1. THE LOOP, driven through a pseudo-terminal because that is the only way to
#    see the screen a student sees.
"$tool" init "$work/course" >/dev/null
python3 - "$work/course" <<'SCRIPT'
import json, pathlib, sys
course = pathlib.Path(sys.argv[1])
# Stand the student in front of the flagship exercise, with the twelve before
# it done, so the progress bar shows a course in progress rather than an empty
# one.
done = [d.name for d in sorted((course / "exercises").iterdir()) if d.name < "13-sub-slices"]
(course / ".odin-tutor" / "progress.json").write_text(
    json.dumps({"completed": done, "welcomed": True}))
# And the attempt that makes the point: a copy, which prints the right answer.
(course / "exercises" / "13-sub-slices" / "start.odin").write_text('''package main

import "core:fmt"

main :: proc() {
	todos := []int{1, 2, 3}
	parte := []int{2, 3}
	fmt.println(len(todos), len(parte))
}
''')
SCRIPT

(cd "$work/course" && printf 'q' | script -qec "$tool" /dev/null) 2>&1 |
	sed 's/\r$//' |
	sed 's/\x1b\[[?0-9;]*[a-zA-Z]//g' |
	sed -n '/── 13-sub-slices/,/q:quit/p' |
	# The terminal echoes the keypress before the loop enters raw mode, so the
	# first line arrives with a stray `q` glued to it.
	sed '1s/^[^─]*//' > "$work/loop.txt"

# 2. THE PICTURE, from the reference solution, at the step where both views
#    exist. Rendered rather than driven: `render` and the interactive screen
#    share one formatter (SPEC-TUI-051), so this is the same text.
"$tool" trace exercises/13-sub-slices/solution.odin "$work/t.json" >/dev/null
steps=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['steps']))" "$work/t.json")
"$tool" render "$work/t.json" "$((steps - 1))" --unicode > "$work/picture.txt"

python3 ci/terminal-to-svg.py "$work/loop.txt" \
	"odin-tutor — the exercise loop" docs/images/loop.svg
python3 ci/terminal-to-svg.py "$work/picture.txt" \
	"odin-tutor — press t, and see the memory" docs/images/picture.svg

echo
echo "regenerated from a real run"
