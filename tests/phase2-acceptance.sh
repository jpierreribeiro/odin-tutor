#!/bin/sh
# The eight acceptance criteria of ROADMAP Phase 2.
#
#   ./tests/phase2-acceptance.sh
#
# Five of them need the real toolchain and are checked here. Three are
# properties of the core alone — linear growth, the known-incorrect identity
# reuse, and identity across a truncated step — and live in `odin test
# src/model`, where they run in milliseconds. This script runs those too, so one
# command answers "is the phase done?".
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
echo "1. two-empty-slices yields two identities; sub-slice yields two views, one"
echo "   storage, lengths 3 and 2, and a recorded sharing relation"

trace_it two-empty-slices
verdict=$(python3 - "$work/two-empty-slices.json" <<'PY'
import json, sys
trace = json.load(open(sys.argv[1]))
best = 0
for step in trace["steps"]:
    for frame in step["frames"]:
        refs = [s.get("refers_to") for s in frame["slots"] if s.get("refers_to")]
        best = max(best, len(set(refs)))
print(best)
PY
)
if [ "$verdict" = "2" ]; then
	ok "two empty slices are two objects"
else
	bad "two empty slices produced $verdict distinct identities, expected 2" \
		"Both are {data: 0x0, len: 0}. Only the holder's address separates them."
fi

trace_it sub-slice
verdict=$(python3 - "$work/sub-slice.json" <<'PY'
import json, sys
trace = json.load(open(sys.argv[1]))
for step in trace["steps"]:
    views = [e for e in step.get("entities", []) if e.get("shares_storage_with")]
    if len(views) != 2:
        continue
    lengths = sorted(v.get("length", 0) for v in views)
    storages = {v["shares_storage_with"] for v in views}
    ids = {v["id"] for v in views}
    if lengths == [2, 3] and len(storages) == 1 and len(ids) == 2:
        print("ok")
        break
else:
    print("no step had two views of lengths 3 and 2 over one storage")
PY
)
if [ "$verdict" = "ok" ]; then
	ok "a sub-slice is a window: two identities, one storage, lengths 3 and 2"
else
	bad "$verdict"
fi

# ---------------------------------------------------------------------------
echo
echo "2. cycle terminates and shows the object's own identifier inside itself"

trace_it cycle
verdict=$(python3 - "$work/cycle.json" <<'PY'
import json, sys
trace = json.load(open(sys.argv[1]))
for step in trace["steps"]:
    for entity in step.get("entities", []):
        for member in entity.get("members", []):
            if member.get("refers_to") == entity["id"]:
                print("ok")
                sys.exit()
print("no member referred to the object it lives in")
PY
)
if [ "$verdict" = "ok" ]; then
	ok "the node's field refers to the node, and the run terminated"
else
	bad "$verdict" "A cycle drawn as a dead end teaches the wrong shape."
fi

# ---------------------------------------------------------------------------
echo
echo "3. corrupt-length yields unknown, and no read exceeds the bound"

trace_it corrupt-length
verdict=$(python3 - "$work/corrupt-length.json.observations" <<'PY'
import json, sys
stream = json.load(open(sys.argv[1]))
UNKNOWN = 3
budgets, reads = stream["budgets"], stream.get("max_reads", {})

saw_unknown = any(
    variable["value"]["state"] == UNKNOWN
    and "not a plausible length" in variable["value"].get("reason", "")
    for record in stream["records"]
    for frame in record["frames"]
    for variable in frame["variables"]
)
elements = reads.get("elements", -1)
within = 0 <= elements <= budgets["elements"]
print("unknown" if saw_unknown else "no-unknown", elements, budgets["elements"], within)
PY
)
set -- $verdict
if [ "$1" = "unknown" ]; then
	ok "the corrupt length produced unknown, not thirty plausible integers"
else
	bad "the corrupt length did not produce unknown"
fi
# ASSERTED BY WHAT WAS READ, not by the absence of a crash. Reading thirty
# integers out of corrupt memory does not crash either, and that is the failure
# being guarded against.
if [ "$4" = "True" ]; then
	ok "the largest element read was $2, within the bound of $3"
else
	bad "the largest element read was $2, against a bound of $3"
fi

# ---------------------------------------------------------------------------
echo
echo "4. invalid-pointer yields unreadable and the run completes"

trace_it invalid-pointer
verdict=$(python3 - "$work/invalid-pointer.json" <<'PY'
import json, sys
trace = json.load(open(sys.argv[1]))
UNREADABLE = 2
unreadable = any(
    member.get("state") == UNREADABLE
    for step in trace["steps"]
    for entity in step.get("entities", [])
    for member in entity.get("members", [])
)
# 0 is Completed. Reaching the end matters as much as the state: a tracer that
# dies on a bad pointer has not reported it, it has been stopped by it.
print("ok" if unreadable and trace["termination"] == 0 else "not-ok",
      unreadable, trace["termination"])
PY
)
set -- $verdict
if [ "$1" = "ok" ]; then
	ok "the unmapped target is unreadable and the run completed"
else
	bad "unreadable=$2 termination=$3, expected a true and a 0"
fi

# ---------------------------------------------------------------------------
echo
echo "5. every fixture traced twice yields equal identities, with address"
echo "   randomisation left ENABLED"

# The whole of Rule 6 rests on this. Identity is a dense counter over a
# deterministic traversal, never an address — so two runs must agree even when
# every address differs.
#
# gdb disables randomisation by default. Left off, this check would pass for a
# reason the claim does not rely on, which is a vacuous test. So the adapter
# turns it back on, and the proof is the pair: the OBSERVATIONS differ between
# runs because they carry addresses, while the identities do not move.
#
# The last check in this section is what keeps the rest honest. If no
# observation stream ever differed, randomisation would not be in effect and
# every comparison above would be proving nothing.
addresses_moved=0
for fixture in scalars sub-slice cycle linked-list-4 two-equal-lists; do
	"$tool" trace "fixtures/programs/$fixture.odin" "$work/a-$fixture.json" >/dev/null
	"$tool" trace "fixtures/programs/$fixture.odin" "$work/b-$fixture.json" >/dev/null

	# IDENTITIES, which is what the criterion states. Comparing whole traces
	# byte for byte is stricter than the claim and fails on any program that
	# reads freed memory - the VALUES there differ between runs while every
	# identity holds. Measured: SPEC-TRACE-062.
	verdict=$(python3 - "$work/a-$fixture.json" "$work/b-$fixture.json" <<'SKEL'
import json, sys

def skeleton(path):
    trace = json.load(open(path))
    out = []
    for step in trace["steps"]:
        for entity in step.get("entities", []):
            out.append((
                entity["id"],
                entity.get("shares_storage_with"),
                entity.get("length"),
                tuple(m.get("refers_to") for m in entity.get("members", [])),
            ))
        for frame in step["frames"]:
            out.append(tuple(s.get("refers_to") for s in frame["slots"]))
    return out

first, second = skeleton(sys.argv[1]), skeleton(sys.argv[2])
print("equal" if first == second else "differ", len(first))
SKEL
)
	set -- $verdict
	if [ "$1" = "equal" ]; then
		ok "$fixture: $2 identity positions equal across two runs"
	else
		bad "$fixture produced two different identity structures" \
			"An identity leaked an address, or the traversal is not deterministic."
	fi

	# Where no freed memory is read, the stronger claim holds and is made.
	case "$fixture" in
	linked-list-4) ;;
	*)
		if cmp -s "$work/a-$fixture.json" "$work/b-$fixture.json"; then
			ok "$fixture is byte-identical across two runs"
		else
			bad "$fixture differs byte for byte" "values moved where no memory was freed"
		fi
		;;
	esac
	if ! cmp -s "$work/a-$fixture.json.observations" "$work/b-$fixture.json.observations"; then
		addresses_moved=$((addresses_moved + 1))
	fi
done

if [ "$addresses_moved" -gt 0 ]; then
	ok "addresses genuinely moved between runs, in $addresses_moved of 5 fixtures"
else
	bad "no observation stream differed between runs" \
		"Randomisation is not in effect, so the checks above proved nothing."
fi

# ---------------------------------------------------------------------------
echo
echo "6, 7, 8. linear growth, the known-incorrect identity reuse, and identity"
echo "         across a truncated step"

if odin test src/model >"$work/model-test.log" 2>&1; then
	count=$(grep -o 'Finished [0-9]* tests' "$work/model-test.log" | grep -o '[0-9]*' || echo "?")
	ok "$count core tests pass, including the three criteria above"
else
	bad "the core test suite failed" "$(grep -E '^\s*-\s' "$work/model-test.log" | head -3)"
fi

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "ROADMAP Phase 2 acceptance: met"
