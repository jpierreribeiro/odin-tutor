#!/bin/sh
# The four acceptance criteria of ROADMAP Phase 5.
#
#   ./tests/phase5-acceptance.sh
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

exercises=$(ls exercises | grep -v README)

# ---------------------------------------------------------------------------
echo
echo "1. every reference solution passes every assertion of its exercise"

for id in $exercises; do
	if "$tool" check "exercises/$id" --entry solution.odin > "$work/$id.pass" 2>&1; then
		count=$(grep -c '^  pass' "$work/$id.pass" || echo 0)
		ok "$id: $count assertions, all passing"
	else
		bad "$id rejected its own reference solution" \
			"$(grep -E '^  (FAIL|undetermined)' "$work/$id.pass" | head -3)"
	fi
done

# ---------------------------------------------------------------------------
echo
echo "2. every exercise rejects at least one plausible wrong solution"

# SPEC-EX-052. An exercise that only accepts the right answer has not been shown
# to distinguish anything - it might accept everything.
for id in $exercises; do
	wrong=$(find "exercises/$id" -name 'wrong-*.odin' | head -1)
	if [ -z "$wrong" ]; then
		bad "$id has no wrong solution to reject" \
			"An exercise with no counter-example is untested."
		continue
	fi
	if "$tool" check "exercises/$id" --entry "$(basename "$wrong")" > "$work/$id.wrong" 2>&1; then
		bad "$id ACCEPTED $(basename "$wrong")" "It accepts a wrong answer."
	else
		ok "$id rejects $(basename "$wrong")"
	fi
done

# THE WORKED EXAMPLE, and the reason this project draws pictures.
#
# The wrong sub-slice solution prints exactly what the reference prints. Every
# test that compares output accepts it. Only the memory assertion separates
# them.
report="$work/13-sub-slices.wrong"
if grep -q '^  pass  *A4' "$report" && grep -q '^  FAIL  *A1' "$report"; then
	ok "the wrong sub-slice passes the OUTPUT assertion and fails the SHARING one"
else
	bad "the worked example did not split output from memory" "$(cat "$report")"
fi

# ---------------------------------------------------------------------------
echo
echo "3. a truncated trace produces undetermined, never fail"

# SPEC-VAL-010, both clauses, one assertion each:
#
#   A1 is an `any` that is never satisfied. On a complete trace that is a fail.
#      On a cut-short one it cannot become "it never happened".
#   A2 is an `all` that holds at every step reached. On a complete trace that is
#      a pass. On a cut-short one it cannot become "it always holds".
#
# Note what is NOT tested here: an assertion that fails for a real reason. A
# variable reported `not-yet-active` is KNOWN evidence, not missing evidence,
# and comparing it against `valid` is a genuine mismatch that must still fail.
# Turning every disagreement into `undetermined` would make the validator
# useless in the other direction.
mkdir -p "$work/truncated"
cat > "$work/truncated/exercise.json" <<'JSON'
{
  "id": "zz-truncated",
  "title": "A trace that was cut short",
  "objective": "Check that missing evidence is never reported as the student's mistake.",
  "concepts": ["slice"],
  "difficulty": 1,
  "entry": "start.odin",
  "assertions": [
    { "id": "A1", "at": "any", "expr": "value_of(\"never_set\") == \"12345\"" },
    { "id": "A2", "at": "all", "expr": "object_count(0)" }
  ]
}
JSON
cat > "$work/truncated/start.odin" <<'ODIN'
package main

// Runs past the step budget, so the trace is cut short.
main :: proc() {
	total := 0
	for i in 0 ..< 100000 {
		total += i
		total -= i
	}
	if total < 0 {
		return
	}
}
ODIN
"$tool" check "$work/truncated" > "$work/truncated.txt" 2>&1 || true
if grep -q '^  FAIL' "$work/truncated.txt"; then
	bad "a cut-short trace produced a FAIL" \
		"$(grep '^  FAIL' "$work/truncated.txt" | head -2)"
else
	ok "no assertion failed on a cut-short trace"
fi
if grep -q '^  undetermined' "$work/truncated.txt"; then
	ok "the missing evidence is reported as undetermined, with its cause"
else
	bad "nothing was reported as undetermined" "$(cat "$work/truncated.txt")"
fi
# And the student is told it is not their mistake.
if grep -q 'not a mistake in your program' "$work/truncated.txt"; then
	ok "the report says plainly that this is the tool's limit"
else
	bad "undetermined was reported without saying whose limit it is"
fi
# undetermined must never be counted as a pass.
if grep -q 'Done. Every assertion passed' "$work/truncated.txt"; then
	bad "undetermined was counted as a pass" "SPEC-VAL-002 forbids exactly this."
else
	ok "undetermined blocks the pass"
fi

# ---------------------------------------------------------------------------
echo
echo "4. no reference solution reaches any budget"

# SPEC-EX-051. An exercise whose own answer hits a limit teaches the student to
# fight the tool.
for id in $exercises; do
	"$tool" trace "exercises/$id/solution.odin" "$work/$id.json" >/dev/null 2>&1
	verdict=$(python3 - "$work/$id.json" <<'SCRIPT'
import json, sys
trace = json.load(open(sys.argv[1]))
hit = [t["what"] for step in trace["steps"] for t in step.get("truncations", [])]
# 0 is Completed: reaching a step or wall budget shows up here rather than as a
# per-step truncation.
print(len(hit), trace["termination"], len(trace["steps"]))
SCRIPT
)
	set -- $verdict
	if [ "$1" = "0" ] && [ "$2" = "0" ]; then
		ok "$id: $3 steps, no budget reached, ran to completion"
	else
		bad "$id reached a budget: $1 truncations, termination $2"
	fi
done

# ---------------------------------------------------------------------------
echo
echo "an exercise is data, not code"

# SPEC-EX-001: the loader executes nothing from the exercise directory except
# the student's Odin source. An exercise with no assertions would accept every
# solution, so the loader refuses it rather than passing everything.
mkdir -p "$work/empty"
printf '{"id":"zz","title":"t","objective":"o","concepts":[],"difficulty":1,"entry":"start.odin","assertions":[]}' \
	> "$work/empty/exercise.json"
printf 'package main\nmain :: proc() {}\n' > "$work/empty/start.odin"
if "$tool" check "$work/empty" > "$work/empty.txt" 2>&1; then
	bad "an exercise with no assertions was accepted" "It would accept anything."
else
	if grep -q 'EXERCISE_INCOMPLETE' "$work/empty.txt"; then
		ok "an exercise with no assertions is refused by name"
	else
		bad "no named error for an exercise with no assertions" "$(head -2 "$work/empty.txt")"
	fi
fi

# ---------------------------------------------------------------------------
echo
echo "there is a student loop, not only a validator"

# THE CRITERION THE ROADMAP DID NOT ASK FOR, and the reason it is here.
#
# The four criteria above all passed while there was NO WAY FOR A STUDENT TO
# START. Every reference solution passed, every exercise rejected a wrong
# solution, truncation was undetermined, no budget was reached - and using any
# of it meant typing an exercise directory and an --entry flag that existed only
# so this script could point at solution.odin.
#
# EXERCISE-SPEC.md §3 described the loop the whole time. Passing tests hid a
# missing goal, in the one layer the rules did not cover, so the checks below
# exist to stop that recurring.
export XDG_STATE_HOME="$work/state"
rm -rf "$XDG_STATE_HOME"

# 1. A bare invocation is the student's command, not a usage error.
if "$tool" list > "$work/list.txt" 2>&1; then
	if grep -qE '0 of [0-9]+ finished' "$work/list.txt"; then
		ok "list shows every exercise with done and not-done"
	else
		bad "list did not report progress" "$(head -4 "$work/list.txt")"
	fi
else
	bad "list failed" "$(head -3 "$work/list.txt")"
fi

# 2. Progress is state the student never types.
python3 - "$XDG_STATE_HOME" <<'SCRIPT'
import json, os, pathlib, sys
root = pathlib.Path(sys.argv[1]) / "odin-tutor"
root.mkdir(parents=True, exist_ok=True)
(root / "progress.json").write_text(json.dumps({"completed": ["01-values"]}))
SCRIPT
if "$tool" list 2>&1 | grep -q 'done  01-values'; then
	ok "a finished exercise is remembered across runs"
else
	bad "progress was not read back"
fi
if "$tool" list 2>&1 | grep -qE '1 of [0-9]+ finished'; then
	ok "and the count reflects it"
else
	bad "the finished count did not move"
fi

# 3. The next exercise is chosen FOR the student.
if "$tool" hint 2>&1 | grep -q "runs the body four times"; then
	ok "hint answers for the exercise the student is on, unnamed"
else
	bad "hint did not pick up the current exercise" \
		"The student would have to know which one they are on."
fi

# 4. Every exercise the course ships can actually be hinted.
for id in $exercises; do
	if [ -f "exercises/$id/hints.md" ]; then
		ok "$id has a hint written"
	else
		bad "$id declares hints and has none" "The field is read now; an empty one is a dead end."
	fi
done
rm -rf "$XDG_STATE_HOME"

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "ROADMAP Phase 5 acceptance: met"
