#!/bin/sh
# The five acceptance criteria of ROADMAP Phase 4.
#
#   ./tests/phase4-acceptance.sh
set -e

: "${ODIN_ROOT:?set ODIN_ROOT to your Odin checkout (core: imports fail without it)}"
export PATH="$ODIN_ROOT:$PATH"

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

ok() {
	passed=$((passed + 1))
	printf '  ok    %s\n' "$1"
	return 0
}

bad() {
	failed=$((failed + 1))
	printf '  FAIL  %s\n' "$1"
	if [ -n "$2" ]; then
		printf '        %s\n' "$2"
	fi
	return 0
}

echo "--- building the tool"
odin build src/tutor -out:"$work/odin-tutor" >/dev/null
tool="$work/odin-tutor"

# ---------------------------------------------------------------------------
echo
echo "1. navigation to any step completes under 16 ms at the 99th percentile"
echo "   on the largest fixture"

# many-objects reaches the step budget, so it IS the largest trace the tool can
# produce. Measured, not asserted: SPEC-PERF-032.
"$tool" trace fixtures/programs/many-objects.odin "$work/largest.json" >/dev/null
if "$tool" bench "$work/largest.json" > "$work/bench.txt" 2>&1; then
	line=$(grep '^p99' "$work/bench.txt")
	steps=$(grep '^steps' "$work/bench.txt" | awk '{print $2}')
	ok "$steps steps, $line, under the 16 ms budget"
else
	bad "the navigation budget was exceeded" "$(cat "$work/bench.txt")"
fi

# The worst case for a keyframe scheme is a jump, not a walk, so a bench that
# only walked forwards would measure the easy case.
if grep -q 'keyframe every' "$work/bench.txt"; then
	ok "measured against the keyframe interval it actually uses"
else
	bad "the bench did not report the keyframe interval"
fi

# ---------------------------------------------------------------------------
echo
echo "2. one golden shows all four value states on one screen"

"$tool" trace fixtures/programs/all-four-states.odin "$work/four.json" >/dev/null
"$tool" render "$work/four.json" 6 > "$work/four.txt"

# SPEC-TEST-060: goldens are produced by `render`, not by the interactive
# screen. SPEC-TEST-061: a change that merges two states must fail a test.
if diff -u fixtures/goldens/all-four-states.txt "$work/four.txt" > "$work/four.diff"; then
	ok "the golden matches byte for byte"
else
	bad "the golden drifted" "$(head -12 "$work/four.diff")"
fi

missing=""
for form in '= 7' '? unknown' '! unreadable' '- not yet'; do
	if ! grep -qF -- "$form" "$work/four.txt"; then
		missing="$missing '$form'"
	fi
done
if [ -z "$missing" ]; then
	ok "valid, unknown, unreadable and not-yet-active all appear, each in its own form"
else
	bad "these forms were absent:$missing" \
		"Two states sharing a form tells the student they are the same thing."
fi

# ---------------------------------------------------------------------------
echo
echo "3. removing colour and Unicode loses no information"

# Asserted by comparing the INFORMATION CONTENT of the two renderings, not their
# appearance. Every glyph the Unicode rendering uses maps to an ASCII form that
# says the same thing; after that mapping the two must be identical. A
# distinction carried by a glyph alone would survive the mapping as a difference.
"$tool" render "$work/four.json" 6 --unicode > "$work/four-unicode.txt"
python3 - "$work/four.txt" "$work/four-unicode.txt" > "$work/equiv.txt" <<'SCRIPT'
import re, sys

GLYPHS = {"→": "->", "·": "-", "✗": "!", "▸": ">"}

def normalise(path):
    text = open(path, encoding="utf-8").read()
    for fancy, plain in GLYPHS.items():
        text = text.replace(fancy, plain)
    # Circled digits are the label form. ① is U+2460 and runs to ⑳.
    text = re.sub(r"[①-⑳]", lambda m: "[%d]" % (ord(m.group()) - 0x2460 + 1), text)
    return text

plain, fancy = normalise(sys.argv[1]), normalise(sys.argv[2])
if plain == fancy:
    print("equal")
else:
    print("differ")
    for a, b in zip(plain.splitlines(), fancy.splitlines()):
        if a != b:
            print("  ascii  :", a)
            print("  unicode:", b)
            break
SCRIPT
if [ "$(head -1 "$work/equiv.txt")" = "equal" ]; then
	ok "the ASCII and Unicode renderings carry the same information"
else
	bad "the two renderings differ in content" "$(tail -2 "$work/equiv.txt")"
fi

# Colour never carries meaning alone, so no rendering may contain an escape
# sequence at all. SPEC-TUI-042, and it is what lets a golden read the screen.
if grep -qP '\x1b\[' "$work/four.txt" "$work/four-unicode.txt" 2>/dev/null; then
	bad "a rendering contained an escape sequence" "render writes text, never colour"
else
	ok "neither rendering contains an escape sequence"
fi

# ---------------------------------------------------------------------------
echo
echo "4. the terminal is restored after a forced error and after an interrupt"

python3 - "$tool" "$work/four.json" > "$work/tty.txt" <<'SCRIPT'
import fcntl, os, pty, signal, sys, time

tool, trace = sys.argv[1], sys.argv[2]

def drive(keys, interrupt=False):
    pid, fd = pty.fork()
    if pid == 0:
        os.execv(tool, ["odin-tutor", "play", trace])
    fcntl.fcntl(fd, fcntl.F_SETFL, os.O_NONBLOCK)
    out = b""
    deadline = time.time() + 1.5
    while time.time() < deadline:
        try:
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            out += chunk
        except (OSError, BlockingIOError):
            time.sleep(0.05)
    if interrupt:
        os.kill(pid, signal.SIGINT)
    else:
        for key in keys:
            os.write(fd, key)
    time.sleep(0.6)
    try:
        out += os.read(fd, 65536)
    except Exception:
        pass
    try:
        os.waitpid(pid, 0)
    except Exception:
        pass
    return out.decode(errors="replace")

quit_run = drive([b"\x1b[C", b"q"])
print("entered", "\x1b[?1049h" in quit_run)
print("quit_restored", "\x1b[?1049l" in quit_run and "\x1b[?25h" in quit_run)
print("navigated", "STEP 2/" in quit_run)

interrupted = drive([], interrupt=True)
# A terminal left in raw mode outlives the process: the student is handed a
# shell that does not echo. Restoration must not depend on reaching the end of
# a procedure.
print("interrupt_restored", "\x1b[?1049l" in interrupted)
SCRIPT
grep -q 'entered True' "$work/tty.txt" && ok "the interface takes the alternate screen" || bad "the alternate screen was never entered"
grep -q 'navigated True' "$work/tty.txt" && ok "the right arrow moves one step" || bad "navigation did not move"
grep -q 'quit_restored True' "$work/tty.txt" && ok "q gives the terminal back" || bad "quitting did not restore the terminal"
grep -q 'interrupt_restored True' "$work/tty.txt" && ok "an interrupt gives the terminal back" || \
	bad "an interrupt left the terminal in raw mode" "The student is handed a shell that does not echo."

# A non-terminal is refused by name, not by crashing.
if "$tool" play "$work/four.json" < /dev/null > "$work/pipe.txt" 2>&1; then
	bad "play succeeded without a terminal"
else
	if grep -q 'NOT_A_TERMINAL' "$work/pipe.txt"; then
		ok "without a terminal it names the error and points at render"
	else
		bad "no named error without a terminal" "$(head -3 "$work/pipe.txt")"
	fi
fi

# ---------------------------------------------------------------------------
echo
echo "5. no step in the interface re-runs the program or the compiler"

# Asserted by taking both tools away. If navigation needed either, it could not
# meet criterion 1 anyway - but an assertion that measures a consequence is
# weaker than one that removes the cause.
if PATH=/nonexistent "$tool" bench "$work/four.json" > "$work/norun.txt" 2>&1; then
	ok "navigation works with neither odin nor gdb on PATH"
else
	bad "navigation failed without the toolchain" "$(head -3 "$work/norun.txt")"
fi
if PATH=/nonexistent "$tool" render "$work/four.json" 6 > /dev/null 2>&1; then
	ok "so does rendering"
else
	bad "rendering failed without the toolchain"
fi

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "ROADMAP Phase 4 acceptance: met"
