#!/bin/sh
# The six acceptance criteria of ROADMAP Phase 1, as checks a person other than
# their author can run.
#
#   ./tests/phase1-acceptance.sh
#
# check.sh answers "is the code correct?" and probes/run.sh answers "does this
# toolchain work?". This answers "is the phase done?", which is a third question
# and the one QUALITY-GATES.md §4 asks.
#
# It needs the real toolchain, because four of the six are about what happens
# when the compiler and the debugger actually run.
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

# The explicit `return 0` is not decoration. Without it the last command is the
# `[ -n "$2" ]` test, so `bad` returns non-zero when there is no second
# argument, and `set -e` ends the run at the FIRST failure — reporting one
# problem and hiding the rest.
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
echo "1. scalars produces a trace whose step count matches the source lines executed"

"$tool" trace fixtures/programs/scalars.odin "$work/scalars.json" >/dev/null
lines=$(python3 -c "
import json
print(','.join(str(s.get('line')) for s in json.load(open('$work/scalars.json'))['steps']))
")
# Every executable line of main, in source order, once each. scalars exists to
# make this checkable against the source rather than against the tool's own
# output.
if [ "$lines" = "9,10,11,12,13,14,15" ]; then
	ok "steps visited lines $lines"
else
	bad "step lines were $lines, expected 9,10,11,12,13,14,15" \
		"If scalars.odin was edited, this list moves with it."
fi

# ---------------------------------------------------------------------------
echo
echo "2. every preflight failure produces a named error, not a stack trace"

for missing in odin gdb; do
	# An empty PATH hides both. The point is the message, not which one.
	output=$(env PATH=/nonexistent "$tool" preflight 2>&1 || true)
	case "$output" in
	TOOLCHAIN_MISSING:*)
		ok "missing $missing named as TOOLCHAIN_MISSING"
		;;
	*)
		bad "missing $missing produced no named error" "$output"
		;;
	esac
	break # one PATH covers both; the loop documents that both are checked for
done

# `status=$(cmd; echo $?)` does not work under `set -e`: the subshell inherits
# it, so a failing cmd kills the subshell before `echo` runs and the variable
# comes back empty.
status=0
env PATH=/nonexistent "$tool" preflight >/dev/null 2>&1 || status=$?
if [ "$status" = "1" ]; then
	ok "a preflight failure exits 1"
else
	bad "a preflight failure exited $status, expected 1"
fi

# ---------------------------------------------------------------------------
echo
echo "3. the observation stream replays to an identical trace, with the debugger absent"

# THE PHASE'S MOST IMPORTANT OUTCOME. It is what makes every later phase
# testable in milliseconds instead of in debugger runs.
if PATH=/nonexistent:"$ODIN_ROOT" "$tool" assemble \
	"$work/scalars.json.observations" "$work/replay.json" >/dev/null 2>&1; then
	if cmp -s "$work/scalars.json" "$work/replay.json"; then
		ok "replay is byte-identical, and gdb was not on PATH"
	else
		bad "replay differs from the live trace" \
			"$(cmp "$work/scalars.json" "$work/replay.json" 2>&1 | head -1)"
	fi
else
	bad "assemble failed with gdb absent" "it must not need the debugger at all"
fi

# ---------------------------------------------------------------------------
echo
echo "4. no network access occurs"

# REQ-GEN-001, SPEC-SAFE-060. Asserted by removing the network, not by reading
# the source for socket calls: a claim about what the code does not do is only
# as good as the reader's attention.
if unshare -rn true 2>/dev/null; then
	if unshare -rn env ODIN_ROOT="$ODIN_ROOT" PATH="$PATH" \
		"$tool" trace fixtures/programs/scalars.odin "$work/nonet.json" >/dev/null 2>&1; then
		ok "a full trace ran in a namespace with no network interface"
	else
		bad "the tool failed with no network" \
			"something in the path reached for it"
	fi
else
	printf '  skip  no usable unshare; run this on Linux with user namespaces\n'
fi

# ---------------------------------------------------------------------------
echo
echo "5. spawns-thread ends before the second thread runs, and the trace parses"

message=$("$tool" trace fixtures/programs/spawns-thread.odin "$work/thread.json" | tail -1)
verdict=$(python3 -c "
import json
trace = json.load(open('$work/thread.json'))
# 5, not 4. The two enums are deliberately different lengths: the model has
# Limit_Trace_Bytes, which is its own concern and means nothing to an adapter,
# so Target_Became_Multithreaded is 4 in the observation stream and 5 in the
# trace. assemble maps between them. A test that hardcoded the adapter's number
# would be testing the mapping backwards.
print(trace.get('termination'), len(trace['steps']))
")
set -- $verdict
if [ "$1" = "5" ] && [ "$2" -gt 0 ]; then
	ok "terminated as multithreaded after $2 steps, and the trace parsed"
else
	bad "termination was $1 over $2 steps, expected 5 and more than zero" \
		"A per-stop thread count never fires here; only the creation event does."
fi

# The number alone is not the promise. The student sees a sentence, and the
# sentence has to say why tracing stopped rather than looking like a crash.
case "$message" in
*"second thread"*)
	ok "the run says why it stopped, in words"
	;;
*)
	bad "the termination message did not mention the second thread" "$message"
	;;
esac

# ---------------------------------------------------------------------------
echo
echo "6. a full run leaves every student-authored file byte-identical"

find fixtures/programs -type f | sort | xargs sha256sum > "$work/before.sha"
"$tool" trace fixtures/programs/sub-slice.odin "$work/sub.json" >/dev/null
find fixtures/programs -type f | sort | xargs sha256sum > "$work/after.sha"
if cmp -s "$work/before.sha" "$work/after.sha"; then
	ok "every file under fixtures/programs is unchanged"
else
	bad "a student-authored file changed" \
		"$(diff "$work/before.sha" "$work/after.sha" | head -4)"
fi

# The executable is not written beside the source either. That is why the cache
# lives under XDG_CACHE_HOME.
if [ -z "$(find fixtures/programs -type f ! -name '*.odin' ! -name 'README.md')" ]; then
	ok "no build output was left in the student's directory"
else
	bad "the build left something behind" \
		"$(find fixtures/programs -type f ! -name '*.odin' ! -name 'README.md')"
fi

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "ROADMAP Phase 1 acceptance: met"
