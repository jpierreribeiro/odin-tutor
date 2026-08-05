#!/bin/sh
# The gate every Phase 7 item shares. SPEC-ADP-020.
#
#   ./tests/adapter-conformance.sh                    check the reference adapter
#   ./tests/adapter-conformance.sh path/to/other.py   check a candidate against it
#
# A new adapter must derive the SAME TRACE from its records as the reference
# adapter, for every fixture. Any difference is explained in that adapter's own
# document, or it is a defect.
#
# This gate is the reason the adapter boundary and the two document formats exist
# ([ADR-003](../docs/decisions/ADR-003-two-document-formats.md)). If it cannot be
# met, the boundary was drawn in the wrong place — and that is worth knowing
# before a second adapter is written, not after.
#
# WHAT IS COMPARED, and what is not:
#
#   compared      the TRACE: identities, references, sharing, lengths, frames,
#                 states, termination. Everything the student is shown.
#   not compared  the OBSERVATION stream. Two adapters may read a program by
#                 different mechanisms and record different addresses; that is
#                 the whole point of having a boundary.
#   not compared  values read from freed memory, which differ run to run on ONE
#                 adapter (SPEC-TRACE-062) and would drown a real difference.
set -e

: "${ODIN_ROOT:?set ODIN_ROOT to your Odin checkout (core: imports fail without it)}"
export PATH="$ODIN_ROOT:$PATH"

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

candidate=${1:-adapter/gdb_extractor.py}
reference=adapter/gdb_extractor.py

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
failed=0
ok() { passed=$((passed + 1)); printf '  ok    %s\n' "$1"; return 0; }
bad() {
	failed=$((failed + 1))
	printf '  FAIL  %s\n' "$1"
	if [ -n "$2" ]; then printf '        %s\n' "$2"; fi
	return 0
}

if [ ! -f "$candidate" ]; then
	echo "no such adapter: $candidate" >&2
	exit 2
fi

echo "--- building the tool"
odin build src/tutor -out:"$work/odin-tutor" >/dev/null
tool="$work/odin-tutor"

echo "reference: $reference"
echo "candidate: $candidate"

# Every fixture, not a chosen few. An adapter that agrees on the easy ones and
# differs on `cycle` has not met the gate.
fixtures=$(find fixtures/programs -name '*.odin' ! -name 'infinite-loop.odin' | sort)

echo
echo "--- tracing every fixture with both adapters"
for source in $fixtures; do
	name=$(basename "$source" .odin)
	TUTOR_ADAPTER="$reference" "$tool" trace "$source" "$work/ref-$name.json" >/dev/null 2>&1 || true
	TUTOR_ADAPTER="$candidate" "$tool" trace "$source" "$work/can-$name.json" >/dev/null 2>&1 || true

	if [ ! -f "$work/ref-$name.json" ]; then
		bad "$name: the reference adapter produced no trace"
		continue
	fi
	if [ ! -f "$work/can-$name.json" ]; then
		bad "$name: the candidate produced no trace" \
			"An adapter that cannot trace a fixture has not met the gate."
		continue
	fi

	verdict=$(python3 - "$work/ref-$name.json" "$work/can-$name.json" "$name" <<'SCRIPT'
import json, sys

# A program that PRINTS what it read from freed memory produces different output
# on every run, on one adapter (R-21, SPEC-TRACE-062). Comparing its stdout would
# fail every candidate for a reason that has nothing to do with the adapter.
#
# Named, not silenced: the exception is one fixture, it is listed here, and the
# run says so on the line. Dropping stdout from the comparison everywhere would
# be the easy fix and would stop the gate from noticing an adapter that loses the
# student's output entirely.
PRINTS_FREED_MEMORY = {"dangling-pointer"}
fixture = sys.argv[3]

def picture(path):
    """Everything the student is shown, and nothing that is an accident of how
    it was read."""
    trace = json.load(open(path))
    out = [trace["termination"], trace.get("exit_code")]
    if fixture not in PRINTS_FREED_MEMORY:
        out.append(trace.get("stdout"))
    for step in trace["steps"]:
        out.append((step["file"], step["line"]))
        for frame in step["frames"]:
            out.append((frame["procedure"], frame.get("returned_text", "")))
            for slot in frame["slots"]:
                # The TEXT of a value is deliberately excluded: a freed region
                # reads differently run to run on one adapter, and that noise
                # would hide a real disagreement about structure.
                out.append((slot["name"], slot["state"], slot.get("refers_to")))
        for entity in step.get("entities", []):
            out.append((entity["id"], entity["type_name"], entity.get("length"),
                        entity.get("shares_storage_with")))
            for member in entity.get("members", []):
                out.append((member["name"], member["state"], member.get("refers_to")))
        for truncation in step.get("truncations", []):
            out.append(("truncated", truncation["what"]))
    return out

a, b = picture(sys.argv[1]), picture(sys.argv[2])
if a == b:
    note = " (stdout excluded: it prints freed memory)" if fixture in PRINTS_FREED_MEMORY else ""
    print("same", str(len(a)) + note.replace(" ", "_"))
else:
    first = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    print("differ", first, repr(a[first:first + 1]), repr(b[first:first + 1]))
SCRIPT
)
	set -- $verdict
	if [ "$1" = "same" ]; then
		ok "$name: $(printf '%s' "$2" | tr '_' ' ') positions, identical picture"
	else
		bad "$name: the two adapters draw different pictures" "at position $2: $3 vs $4"
	fi
done

# ---------------------------------------------------------------------------
echo
echo "--- the negative control"

# A gate that nothing can fail proves nothing. This adapter is the reference with
# one line changed: it reports every slice as one element shorter. If the
# comparison above cannot catch that, it cannot catch a real disagreement either.
sed 's/^        "length": length,$/        "length": max(0, length - 1),/' \
	"$reference" > "$work/broken.py"
if cmp -s "$reference" "$work/broken.py"; then
	bad "the negative control was not modified" \
		"The gate is untested, so its passes above mean nothing."
else
	TUTOR_ADAPTER="$work/broken.py" "$tool" trace fixtures/programs/sub-slice.odin \
		"$work/broken.json" >/dev/null 2>&1 || true
	if [ ! -f "$work/broken.json" ]; then
		ok "the broken adapter could not even produce a trace"
	else
		verdict=$(python3 - "$work/ref-sub-slice.json" "$work/broken.json" <<'SCRIPT'
import json, sys

def lengths(path):
    trace = json.load(open(path))
    return [e.get("length") for step in trace["steps"] for e in step.get("entities", [])]

print("caught" if lengths(sys.argv[1]) != lengths(sys.argv[2]) else "missed")
SCRIPT
)
		if [ "$verdict" = "caught" ]; then
			ok "a one-line change to the adapter is caught by the comparison"
		else
			bad "the comparison did not notice a deliberately broken adapter" \
				"A gate that nothing can fail proves nothing."
		fi
	fi
fi

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "SPEC-ADP-020 conformance: met"
