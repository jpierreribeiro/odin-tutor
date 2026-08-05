#!/bin/sh
# ROADMAP Phase 6a — allocator observation, free events only.
#
#   ./tests/phase6-acceptance.sh
#
# Acceptance: `free-then-allocate` yields two identities, and its Phase 2 test —
# which asserted the incorrect behaviour — is replaced, not deleted quietly.
# REQ-MEM-003 becomes fully met.
set -e

: "${ODIN_ROOT:?set ODIN_ROOT to your Odin checkout (core: imports fail without it)}"
export PATH="$ODIN_ROOT:$PATH"

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

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

echo "--- building the tool"
odin build src/tutor -out:"$work/odin-tutor" >/dev/null
tool="$work/odin-tutor"

# ---------------------------------------------------------------------------
echo
echo "1. free-then-allocate yields TWO identities"

"$tool" trace fixtures/programs/free-then-allocate.odin "$work/fta.json" >/dev/null
verdict=$(python3 - "$work/fta.json" <<'SCRIPT'
import json, sys
trace = json.load(open(sys.argv[1]))

# The question is not "does `first` ever equal `second`" - after the free,
# `first` is a DANGLING pointer and names whatever now lives there, which the
# tool cannot know (R-21). The question is whether the object that lived at that
# address before the free and the one that lives there after are two identities.
before, after = None, None
for step in trace["steps"]:
    for frame in step["frames"]:
        for slot in frame["slots"]:
            if slot["name"] == "first" and slot.get("refers_to") and before is None:
                before = slot["refers_to"]
            if slot["name"] == "second" and slot.get("refers_to"):
                after = slot["refers_to"]
print(before, after)
SCRIPT
)
set -- $verdict
if [ "$1" != "None" ] && [ "$2" != "None" ] && [ "$1" != "$2" ]; then
	ok "the object before the free is [$1] and the one after is [$2]"
else
	bad "one identity was reused across a free: [$1] and [$2]" \
		"A student would see one object that changed value, where two lived and died."
fi

# ---------------------------------------------------------------------------
echo
echo "2. the death is recorded from the program, not inferred"

verdict=$(python3 - "$work/fta.json.observations" <<'SCRIPT'
import json, sys
stream = json.load(open(sys.argv[1]))
frees = [a for record in stream["records"] for a in record.get("freed", [])]
objects = {o["address"] for record in stream["records"] for o in record.get("objects", [])}
# The recorded address must be where the OBJECT lives. Measured: the obvious
# symbol, runtime::heap_free, reports 8 bytes below that - the allocator's own
# base pointer. Matching it would never match, and correcting it by a guessed
# offset risks killing a live object instead.
matched = len(objects & set(frees))
print(len(frees), matched)
SCRIPT
)
set -- $verdict
if [ "$1" -gt 0 ]; then
	ok "$1 free events recorded from the program"
else
	bad "no free events were recorded" \
		"Phase 6a exists only because the free-symbol probe found an entry point."
fi
if [ "$2" -gt 0 ]; then
	ok "$2 of them name an address an object actually lives at"
else
	bad "no free event matched an object address" \
		"The adapter is watching the wrong symbol: heap_free is 8 bytes low."
fi

# ---------------------------------------------------------------------------
echo
echo "3. a free event is not needed to be safe, only to be precise"

# Without evidence of death the model must NOT invent one. The absence rule and
# its ADR-011 guard are still there, and a toolchain whose allocator entry point
# does not resolve keeps the version 1 behaviour rather than failing.
if odin test src/model > "$work/model.log" 2>&1; then
	if grep -q 'without_a_free_event_still_reuses_the_identity' src/model/model_test.odin; then
		ok "the no-evidence case still has a test, renamed rather than deleted"
	else
		bad "the version 1 test was deleted rather than replaced" \
			"SPEC-TEST-021 requires the replacement to be loud."
	fi
	if grep -q 'a_recorded_free_gives_the_next_allocation_a_new_identity' src/model/model_test.odin; then
		ok "and its successor asserts the new behaviour"
	else
		bad "no test asserts the closed behaviour"
	fi
else
	bad "the core test suite failed" "$(grep -E '^\s*-\s' "$work/model.log" | head -3)"
fi

# ---------------------------------------------------------------------------
echo
echo "4. nothing else moved"

# The other anti-lie fixtures must be unchanged by this. A free event that
# advanced an epoch it should not would split a LIVE object in two, which is a
# worse lie than the one Phase 6 closed.
for fixture in cycle linked-list-4 sub-slice two-empty-slices; do
	"$tool" trace "fixtures/programs/$fixture.odin" "$work/a-$fixture.json" >/dev/null
	"$tool" trace "fixtures/programs/$fixture.odin" "$work/b-$fixture.json" >/dev/null
	# Identities, not bytes. linked-list-4 reads through pointers it has freed,
	# and those VALUES differ between runs while every identity holds — measured
	# and recorded as SPEC-TRACE-062. Comparing bytes would fail it for a reason
	# that has nothing to do with this phase.
	verdict=$(python3 - "$work/a-$fixture.json" "$work/b-$fixture.json" <<'SKEL'
import json, sys

def skeleton(path):
    trace = json.load(open(path))
    out = []
    for step in trace["steps"]:
        for entity in step.get("entities", []):
            out.append((entity["id"], entity.get("shares_storage_with"),
                        tuple(m.get("refers_to") for m in entity.get("members", []))))
        for frame in step["frames"]:
            out.append(tuple(s.get("refers_to") for s in frame["slots"]))
    return out

print("equal" if skeleton(sys.argv[1]) == skeleton(sys.argv[2]) else "differ")
SKEL
)
	if [ "$verdict" = "equal" ]; then
		ok "$fixture keeps the same identities across two runs"
	else
		bad "$fixture stopped being deterministic in its identities" \
			"A free event that fired differently between runs would do this."
	fi
done

verdict=$(python3 - "$work/a-cycle.json" <<'SCRIPT'
import json, sys
trace = json.load(open(sys.argv[1]))
for step in trace["steps"]:
    for entity in step.get("entities", []):
        for member in entity.get("members", []):
            if member.get("refers_to") == entity["id"]:
                print("ok")
                sys.exit()
print("lost")
SCRIPT
)
if [ "$verdict" = "ok" ]; then
	ok "the cycle still shows its own identifier"
else
	bad "the cycle stopped showing its own identifier"
fi

# ---------------------------------------------------------------------------
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
echo
echo "ROADMAP Phase 6a acceptance: met"
