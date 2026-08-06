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

# AND IT IS REJECTED BY THE PICTURE, not merely by its printed output.
#
# SPEC-EX-052 asks that a wrong solution be rejected. That is not enough on its
# own: an exercise whose counter-example fails only an `output_equals` would be
# caught by any test runner ever written, and needs none of this project.
#
# Measured 2026-08-06: two exercises were in exactly that state. `05-pointers`
# kept its pointer variable in the wrong answer so every memory assertion passed
# on both, and `16-utf8` padded to ten ASCII letters so the length matched. Both
# now assert on something only the picture holds.
echo
echo "2b. and the picture is what rejects it, not the printed output"
weak=""
for id in $exercises; do
	report="$work/$id.wrong"
	[ -f "$report" ] || continue
	failing=$(grep -E '^  (FAIL|undetermined)' "$report" | awk '{print $2}' | tr '\n' ' ')
	kind=$(python3 - "exercises/$id/exercise.json" "$failing" <<'SCRIPT'
import json, sys
declared = json.load(open(sys.argv[1]))["assertions"]
failed = set(sys.argv[2].split())
kinds = set()
for a in declared:
    if a["id"] in failed:
        text = a["expr"]
        kinds.add("output" if "output_" in text or "exits_with" in text else "memory")
print("memory" if "memory" in kinds else ("output" if kinds else "nothing"))
SCRIPT
)
	[ "$kind" = "memory" ] || weak="$weak $id"
done
if [ -z "$weak" ]; then
	ok "every exercise rejects its wrong answer by an assertion about MEMORY"
else
	bad "rejected only by printed output:$weak" \
		"Any test runner catches those. They do not need this project."
fi

# ---------------------------------------------------------------------------
echo
echo "2c. every start.odin compiles, and none of them already passes"

# What a student meets FIRST. A start that does not compile is a compiler error
# where an exercise was meant, and a start that already passes is an exercise
# with nothing to do — neither is caught by any criterion above, because both
# are about the file nobody tests.
for id in $exercises; do
	if odin build "exercises/$id/start.odin" -file -out:"$work/start-$id" > "$work/start-$id.txt" 2>&1; then
		if "$tool" check "exercises/$id" > /dev/null 2>&1; then
			bad "$id: start.odin already passes" "There is nothing for the student to do."
		else
			ok "$id: start.odin compiles and does not pass yet"
		fi
	else
		bad "$id: start.odin does not compile" "$(head -2 "$work/start-$id.txt")"
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
echo "ROADMAP Phase 5b — the shell around the loop"

# The seven differences between this tool and rustlings, found by putting them
# side by side rather than by reading the plan. Each one is checked here as it
# lands, for the same reason the section above exists: the loop itself was
# missing once while every criterion of Phase 5 passed.
student="$work/student"
mkdir -p "$student"
# The exercises `init` copies FROM. Named rather than searched for, which is
# also the path an installed build uses.
export TUTOR_EXERCISES="$root/exercises"
# The adapter is found beside the executable in an installed build. This script
# builds the tool into a scratch directory, so it is named here instead — the
# working directory is deliberately not one of the places it is looked for
# (SPEC-SAFE-040), and after `init` the working directory is the student's.
export TUTOR_ADAPTER="$root/adapter/gdb_extractor.py"

pristine="$work/pristine-01-values.odin"
cp exercises/01-values/start.odin "$pristine"

# 1. init: the student stops editing inside the repository.
(cd "$student" && "$tool" init mine) > "$work/init.txt" 2>&1 || true
if [ -f "$student/mine/exercises/01-values/start.odin" ] &&
	[ -f "$student/mine/.odin-tutor/course.json" ]; then
	ok "init copies the course into a directory of the student's own"
else
	bad "init did not create a student course" "$(cat "$work/init.txt")"
fi

# THE POINT OF INIT. Before it, the student's answers and the course's history
# were the same files, so `git status` was never clean again.
if cmp -s "$pristine" exercises/01-values/start.odin; then
	ok "and it writes nothing into the course's own tree"
else
	bad "init modified the course's own exercises" "The student's tree must be a copy."
fi

copied=$(ls "$student/mine/exercises" | wc -l)
declared=$(echo "$exercises" | wc -w)
if [ "$copied" -eq "$declared" ]; then
	ok "every exercise is copied ($copied)"
else
	bad "init copied $copied of $declared exercises"
fi

# A directory of deliberately broken answers is confusing to read and pointless
# to open. The counter-examples belong to this script, not to the student.
if find "$student/mine/exercises" -name 'wrong-*.odin' | grep -q .; then
	bad "the wrong solutions were handed to the student"
else
	ok "the counter-examples are not part of what a student is given"
fi

if (cd "$student" && "$tool" init mine) > "$work/init2.txt" 2>&1; then
	bad "init overwrote a directory that already existed" "That is somebody's answers."
else
	if grep -q 'OCCUPIED' "$work/init2.txt"; then
		ok "init refuses an existing directory by name, rather than overwriting it"
	else
		bad "init failed without saying why" "$(head -2 "$work/init2.txt")"
	fi
fi

# 1b. The command init tells the student to run has to BE A COMMAND.
#
# It printed `odin-tutor`, which is `command not found` for everyone who built
# this from a checkout — the next line of their session, every time.
runnable=$(grep -A2 '^  cd ' "$work/init.txt" | sed -n '2p' | sed 's/^  //')
if [ -x "$runnable" ] || command -v "$runnable" > /dev/null 2>&1; then
	ok "init prints a command that exists on the machine it printed it on"
else
	bad "init told the student to run something that is not there: '$runnable'" \
		"$(sed -n '/^  cd /,+3p' "$work/init.txt")"
fi

# 1c. AN INSTALLED COPY, reached through the PATH.
#
# This is what the README tells a student to set up, and until this check it was
# broken: found through the PATH, argv[0] is the bare word `odin-tutor`, so
# everything looked for "beside the executable" was looked for beside whatever
# directory the student was standing in. `init` found no course to copy, and a
# trace found no script to run inside gdb.
#
# The environment variables that name both are UNSET here on purpose. They are
# how the rest of this script points at a checkout, and they would hide exactly
# the bug this checks for.
installed="$work/bin"
mkdir -p "$installed/adapter"
cp "$tool" "$installed/odin-tutor"
cp adapter/gdb_extractor.py "$installed/adapter/"
cp -r exercises "$installed/"
find "$installed/exercises" -name 'wrong-*.odin' -delete

(cd "$work" && env -u TUTOR_EXERCISES -u TUTOR_ADAPTER PATH="$installed:$PATH" \
	odin-tutor init from-path) > "$work/from-path.txt" 2>&1 || true
if [ -f "$work/from-path/exercises/01-values/start.odin" ]; then
	ok "an installed copy on the PATH finds its own exercises"
else
	bad "init from a PATH install found no course" "$(head -3 "$work/from-path.txt")"
fi

# And the debugger script too, which is the half that fails later and louder.
(cd "$work/from-path" && env -u TUTOR_EXERCISES -u TUTOR_ADAPTER PATH="$installed:$PATH" \
	odin-tutor check exercises/01-values --entry solution.odin) > "$work/from-path-trace.txt" 2>&1 || true
if grep -q 'Done. Every assertion passed' "$work/from-path-trace.txt"; then
	ok "and it traces, so it found its adapter beside itself rather than beside the student"
else
	bad "a PATH install could not trace" "$(tail -3 "$work/from-path-trace.txt")"
fi

# 2. The tool run from inside that directory works on THAT course.
(cd "$student/mine/exercises/01-values" && "$tool" list) > "$work/inside.txt" 2>&1 || true
if grep -qE "0 of $declared finished" "$work/inside.txt"; then
	ok "the course is found from anywhere inside it, without naming a path"
else
	bad "the student's course was not found from a subdirectory" "$(head -3 "$work/inside.txt")"
fi

# 3. A progress bar, and it is the renderer's, not a second formatter.
if grep -q 'Progress: \[' "$work/inside.txt" && grep -q '>' "$work/inside.txt"; then
	ok "a progress bar is drawn, with a position in it"
else
	bad "no progress bar" "$(tail -3 "$work/inside.txt")"
fi

# 4. reset: there is a way back that is not `git checkout`.
printf 'ruined\n' > "$student/mine/exercises/01-values/start.odin"
(cd "$student/mine" && "$tool" reset) > "$work/reset.txt" 2>&1 || true
if cmp -s "$pristine" "$student/mine/exercises/01-values/start.odin"; then
	ok "reset puts the exercise back exactly as it was handed over"
else
	bad "reset did not restore the file" "$(cat "$work/reset.txt")"
fi

# And it is honest about the one case it cannot serve.
(cd "$root" && "$tool" reset) > "$work/reset-repo.txt" 2>&1 || true
if grep -q 'NO_ORIGINAL' "$work/reset-repo.txt"; then
	ok "a course that was not made by init says so instead of guessing"
else
	bad "reset in the repository did not name its limit" "$(head -2 "$work/reset-repo.txt")"
fi
if cmp -s "$pristine" exercises/01-values/start.odin; then
	ok "and it wrote nothing while refusing"
else
	bad "a refused reset still modified the repository"
fi

# 5. Progress belongs to the student's copy, not to one path per machine.
python3 - "$student/mine" <<'SCRIPT'
import json, pathlib, sys
state = pathlib.Path(sys.argv[1]) / ".odin-tutor" / "progress.json"
state.write_text(json.dumps({"completed": ["01-values"], "welcomed": True}))
SCRIPT
if (cd "$student/mine" && "$tool" list) 2>&1 | grep -q 'done  01-values'; then
	ok "progress is kept in the student's own directory"
else
	bad "the course did not read back its own progress"
fi
if "$tool" list 2>&1 | grep -qE "0 of $declared finished"; then
	ok "and a second course does not inherit it"
else
	bad "two courses share one count" "Each copy must count its own."
fi

# 6. The interactive loop, driven through a pseudo-terminal.
#
# Every check below needs a real terminal, because that is the whole subject:
# keys read inside the loop, a bar under every screen, and an exercise that does
# not end until the student says so.
if ! command -v script > /dev/null 2>&1; then
	printf '  SKIP  the interactive loop was NOT checked: `script` is not installed\n'
	printf '        Install util-linux to run these. They are not optional criteria.\n'
else
	cp "$student/mine/exercises/01-values/solution.odin" \
		"$student/mine/exercises/01-values/start.odin"
	rm -f "$student/mine/.odin-tutor/progress.json"

	# ENTER past the introduction, then `n` and `q`: solve the first exercise,
	# move on, leave.
	(cd "$student/mine" && printf '\nnq' | timeout 300 script -qec "$tool" /dev/null) \
		> "$work/loop1.txt" 2>&1 || true

	if grep -q 'Welcome to odin-tutor' "$work/loop1.txt"; then
		ok "a first run explains what an exercise is and how the loop behaves"
	else
		bad "no first-run explanation" "$(head -5 "$work/loop1.txt")"
	fi
	if grep -q 'Current exercise: exercises/01-values/start.odin' "$work/loop1.txt"; then
		ok "the path being edited is on screen, relative to the course"
	else
		bad "the current exercise path is not shown" "$(grep -c . "$work/loop1.txt") lines"
	fi
	if grep -q 'q:quit' "$work/loop1.txt" && grep -q 'x:reset' "$work/loop1.txt"; then
		ok "the keys are on screen, so none of them has to be remembered"
	else
		bad "no key bar" "$(tail -5 "$work/loop1.txt")"
	fi
	if grep -q 'Solution for comparison: exercises/01-values/solution.odin' "$work/loop1.txt"; then
		ok "a passing exercise points at the reference solution"
	else
		bad "solution.odin exists and was never mentioned"
	fi

	# THE DECISION, not a gap (ROADMAP Phase 5b). A solved exercise is the one
	# moment the student can change a line and watch the picture change with it.
	# This tool waits for `n` rather than taking that away to save a keypress.
	if grep -q 'When done experimenting, enter `n` to move on' "$work/loop1.txt" &&
		grep -q 'n:next' "$work/loop1.txt"; then
		ok "a solved exercise waits for the student rather than advancing itself"
	else
		bad "the loop advanced without being asked" "ROADMAP Phase 5b records the opposite."
	fi
	if grep -q '02-control-flow' "$work/loop1.txt"; then
		ok "and n moves on to the next one"
	else
		bad "n did not advance" "$(tail -6 "$work/loop1.txt")"
	fi
	if grep -q '02-control-flow' "$work/loop1.txt" &&
		grep -qE "Progress: \[#+>[-]*\]  1/$declared" "$work/loop1.txt"; then
		ok "the bar counts what was finished, and only that"
	else
		bad "the progress bar did not move after an exercise passed" \
			"$(grep 'Progress:' "$work/loop1.txt" | tail -2)"
	fi

	# `t`, `q`, `q`: open the picture where the assertion was decided, come back,
	# leave. SPEC-EX-020, and the reason this project is not a compile-error
	# tutorial.
	(cd "$student/mine" && printf 'tqq' | timeout 300 script -qec "$tool" /dev/null) \
		> "$work/loop2.txt" 2>&1 || true

	if grep -q 'Welcome to odin-tutor' "$work/loop2.txt"; then
		bad "the introduction was shown a second time" "It is state, not a preference."
	else
		ok "the introduction is shown once and then not again"
	fi
	if grep -q 'n:next' "$work/loop2.txt"; then
		bad "n was offered on an unsolved exercise" "It would be an instruction the tool refuses."
	else
		ok "a key that does nothing yet is not on the bar"
	fi
	if grep -q 'press `t` to look at it' "$work/loop2.txt"; then
		ok "a failing assertion names the step it was decided at"
	else
		bad "no step was named for a failing assertion" "$(tail -6 "$work/loop2.txt")"
	fi
	if grep -q 'g jump' "$work/loop2.txt" && grep -q 'FRAMES' "$work/loop2.txt"; then
		ok "and t opens the picture there, inside the loop (SPEC-EX-020)"
	else
		bad "t did not open the step player" "$(tail -8 "$work/loop2.txt")"
	fi

	# `c`, on a course of two, because it builds and runs every exercise it can
	# see and this script already runs all sixteen three times over.
	(cd "$work" && "$tool" init small) > /dev/null 2>&1 || true
	(cd "$work/small/exercises" &&
		ls | grep -vE '01-values|02-control-flow' | xargs rm -rf) 2>/dev/null || true
	cp "$work/small/exercises/01-values/solution.odin" \
		"$work/small/exercises/01-values/start.odin"
	(cd "$work/small" && printf '\ncq' | timeout 300 script -qec "$tool" /dev/null) \
		> "$work/loop3.txt" 2>&1 || true

	if grep -q 'pass  01-values' "$work/loop3.txt" &&
		grep -q 'not   02-control-flow' "$work/loop3.txt"; then
		ok "c checks every exercise, not only the one being watched"
	else
		bad "check all did not report every exercise" "$(tail -6 "$work/loop3.txt")"
	fi
	if grep -q '"01-values"' "$work/small/.odin-tutor/progress.json" 2>/dev/null; then
		ok "and what it found passing is recorded, not just printed"
	else
		bad "check all printed a pass it did not record" \
			"Work done outside the watched exercise would not count."
	fi
fi

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "ROADMAP Phase 5 acceptance: met"
