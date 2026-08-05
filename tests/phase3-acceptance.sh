#!/bin/sh
# The four acceptance criteria of ROADMAP Phase 3.
#
#   ./tests/phase3-acceptance.sh
#
# THE RULE FOR THIS PHASE, from the roadmap: a partial success is acceptable and
# a false success is not. Shipping with return values withheld everywhere is a
# valid outcome. Shipping with return values that are usually right is not.
#
# That is why criteria 2 and 3 are a PAIR and neither means anything alone.
# Criterion 2 forbids the lie; criterion 3 requires the value where it is
# knowable. A tool that shows nothing passes 2 and fails 3, which is exactly how
# a prior system's "return never lies" check became vacuously true once the code
# stopped emitting the values it inspected, and nothing noticed.
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

trace_it() {
	"$tool" trace "fixtures/programs/$1.odin" "$work/$1.json" >/dev/null
}

# ---------------------------------------------------------------------------
echo
echo "1. two-calls-one-line yields two frame identities"

trace_it two-calls-one-line
verdict=$(python3 - "$work/two-calls-one-line.json" <<'SCRIPT'
import json, sys
trace = json.load(open(sys.argv[1]))
ids, returns = set(), {}
for step in trace["steps"]:
    for frame in step["frames"]:
        if frame["procedure"].endswith("double"):
            ids.add(frame["id"])
            if frame.get("returned_text"):
                returns[frame["id"]] = frame["returned_text"]
print(len(ids), ",".join(sorted(returns.values())))
SCRIPT
)
set -- $verdict
if [ "$1" = "2" ]; then
	ok "two calls on one source line are two invocations"
else
	bad "double got $1 frame identities, expected 2" \
		"A key built from the source position alone merges them. Two calls on one line are two call sites, so two return addresses."
fi
# And they are told apart correctly, not merely counted: double(1) and double(2).
if [ "$2" = "2,4" ]; then
	ok "each invocation carries its own return value: $2"
else
	bad "the two invocations returned $2, expected 2,4" \
		"Counting two identities is not the same as attributing to the right one."
fi

# ---------------------------------------------------------------------------
echo
echo "2. in fibonacci, NO shown return value contradicts its frame's argument"

trace_it fibonacci
verdict=$(python3 - "$work/fibonacci.json" <<'SCRIPT'
import json, sys
FIB = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
trace = json.load(open(sys.argv[1]))
shown, wrong = 0, 0
for step in trace["steps"]:
    for frame in step["frames"]:
        text = frame.get("returned_text")
        if not text:
            continue
        shown += 1
        argument = None
        for slot in frame["slots"]:
            if slot["name"] == "n" and slot.get("text"):
                argument = int(slot["text"])
        # A frame whose argument is not readable cannot be checked, and a value
        # shown against an uncheckable frame is exactly the unattributable case
        # SPEC-MEM-061 says to withhold.
        if argument is None or not (0 <= argument < len(FIB)) or int(text) != FIB[argument]:
            wrong += 1
print(shown, wrong)
SCRIPT
)
set -- $verdict
if [ "$2" = "0" ]; then
	ok "$1 return values shown, none contradicting its frame"
else
	bad "$2 of $1 shown return values contradict their frame's argument" \
		"A frame holding n = 0 reporting 8 teaches that fib(0) is 8."
fi

# ---------------------------------------------------------------------------
echo
echo "3. in simple-call, the return value IS shown"

# Without this, criterion 2 passes by showing nothing at all.
trace_it simple-call
verdict=$(python3 - "$work/simple-call.json" <<'SCRIPT'
import json, sys
trace = json.load(open(sys.argv[1]))
for step in trace["steps"]:
    for frame in step["frames"]:
        if frame["procedure"].endswith("double") and frame.get("returned_text"):
            print(frame["returned_text"])
            sys.exit()
print("none")
SCRIPT
)
if [ "$verdict" = "42" ]; then
	ok "double(21) is shown returning 42"
else
	bad "simple-call showed '$verdict', expected 42" \
		"Withholding everywhere passes criterion 2 while teaching nothing."
fi

# ---------------------------------------------------------------------------
echo
echo "4. prologue shows not-yet-active, and the renderer does not say 'no variables'"

trace_it prologue
verdict=$(python3 - "$work/prologue.json" <<'SCRIPT'
import json, sys
NOT_YET_ACTIVE = 1
trace = json.load(open(sys.argv[1]))
found = any(
    slot["state"] == NOT_YET_ACTIVE
    for step in trace["steps"]
    for frame in step["frames"]
    if frame["procedure"].endswith("add")
    for slot in frame["slots"]
)
print("ok" if found else "none")
SCRIPT
)
if [ "$verdict" = "ok" ]; then
	ok "an argument read before the prologue ran is not-yet-active"
else
	bad "no not-yet-active state in add's frame" \
		"Measured: fib at its declaration line reported n = 140737488342512."
fi

# The renderer must NOT say the frame is empty. "Not created yet" and "there are
# no variables" are different statements, and only one of them is true here.
rendered=$("$tool" render "$work/prologue.json" 3)
if printf '%s' "$rendered" | grep -q 'not created yet'; then
	ok "the render names the state instead of the frame being empty"
else
	bad "the render did not show a not-yet-active variable" "$rendered"
fi
if printf '%s' "$rendered" | grep -qi 'no variables'; then
	bad "the render claimed the frame has no variables" \
		"It has variables. They are not born yet, which is a different fact."
else
	ok "the render does not claim the frame has no variables"
fi

# ---------------------------------------------------------------------------
echo
echo "the phase's other two fixtures"

# deep-recursion: frame identity where a per-frame cost or a key collision would
# show up. The probe walked depth 7; this is 100.
trace_it deep-recursion
verdict=$(python3 - "$work/deep-recursion.json" <<'SCRIPT'
import json, sys
trace = json.load(open(sys.argv[1]))
ids, shown, wrong = set(), 0, 0
for step in trace["steps"]:
    for frame in step["frames"]:
        if not frame["procedure"].endswith("count_down"):
            continue
        ids.add(frame["id"])
        text = frame.get("returned_text")
        if not text:
            continue
        shown += 1
        argument = None
        for slot in frame["slots"]:
            if slot["name"] == "n" and slot.get("text"):
                argument = int(slot["text"])
        # count_down(n) returns n.
        if argument is None or int(text) != argument:
            wrong += 1
print(len(ids), shown, wrong)
SCRIPT
)
set -- $verdict
if [ "$1" -ge 100 ] && [ "$3" = "0" ]; then
	ok "deep-recursion: $1 distinct frame identities, $2 returns, none wrong"
else
	bad "deep-recursion: $1 identities, $2 returns, $3 wrong" \
		"Expected at least 100 identities and no wrong value."
fi

# uninitialised-local RECORDS A LIMIT (R-22) rather than asserting a safeguard.
# `= ---` generates no code, so its declaring line is never a step, and the tool
# reads whatever the previous call left. Asserted so a change is loud.
trace_it uninitialised-local
verdict=$(python3 - "$work/uninitialised-local.json" <<'SCRIPT'
import json, sys
NOT_YET_ACTIVE = 1
trace = json.load(open(sys.argv[1]))
y_withheld = False
x_after = None
for step in trace["steps"]:
    for frame in step["frames"]:
        for slot in frame["slots"]:
            if slot["name"] == "y" and slot["state"] == NOT_YET_ACTIVE:
                y_withheld = True
            if slot["name"] == "x" and slot.get("text") == "2":
                x_after = "2"
print("ok" if y_withheld else "no-y", x_after or "none")
SCRIPT
)
set -- $verdict
if [ "$1" = "ok" ]; then
	ok "a local read before its declaration line is still withheld"
else
	bad "y was not withheld before its declaration line"
fi
if [ "$2" = "2" ]; then
	ok "and the value is correct once assigned"
else
	bad "x after assignment showed '$2', expected 2"
fi

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "ROADMAP Phase 3 acceptance: met"
