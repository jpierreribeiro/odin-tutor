#!/bin/sh
# The probe suite. SPEC-TEST-041, SPEC-TEST-040.
#
# Answers "does this toolchain work?", separately from check.sh, which answers
# "is this code correct?". A row in the compatibility table
# (PLATFORM-SUPPORT.md §5) may only be added when this passes and its report is
# committed under fixtures/toolchain/ (SPEC-PLAT-031).
#
#   ./probes/run.sh                     write the report for today's date
#   ./probes/run.sh --out <path>        write it somewhere else
#
# Exit code: 0 unless a BLOCKING probe failed. A HIGH or MEDIUM failure is a
# recorded fact about the platform, not a broken build (SPEC-TEST-042) — and
# `only-student-code` is EXPECTED to fail, which is why SPEC-ADP-014 exists.
set -e

: "${ODIN_ROOT:?set ODIN_ROOT to your Odin checkout (core: imports fail without it)}"
export PATH="$ODIN_ROOT:$PATH"

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

out=""
while [ $# -gt 0 ]; do
	case "$1" in
	--out) out="$2"; shift 2 ;;
	*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done

if [ -z "$out" ]; then
	out="fixtures/toolchain/$(date +%F)-$(uname -s | tr 'A-Z' 'a-z')-$(uname -m).md"
fi

if [ -e "$out" ]; then
	echo "refusing to overwrite $out" >&2
	echo "A committed probe report is evidence for a row in the compatibility" >&2
	echo "table. Pass --out <path> to write elsewhere." >&2
	exit 2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
raw="$work/results.jsonl"
: > "$raw"

echo "--- preflight"
if ! gdb --configuration 2>/dev/null | grep -q -- '--with-python'; then
	# Not fatal by itself: some builds report Python differently. The suite will
	# fail loudly on the first group if Python is genuinely absent.
	echo "warning: gdb --configuration does not mention Python"
fi
odin version
gdb --version | head -1
echo "ODIN_ROOT=$ODIN_ROOT"

# probe <group> <source> [--no-debug]
probe() {
	group=$1
	source=$2
	flags="-debug"
	[ "$3" = "--no-debug" ] && flags=""

	name=$(basename "$source" .odin)
	binary="$work/$name${3:+-stripped}"

	# shellcheck disable=SC2086 # flags is intentionally word-split
	odin build "$source" -file $flags -out:"$binary" >/dev/null

	printf '%-16s %s\n' "$group" "$(basename "$source")"

	# -nx: the debugger must not be scriptable from the working directory
	# (SPEC-SAFE-040).
	log="$work/$group-$name.log"
	PROBE="$group" PROBE_SOURCE="$root/$source" \
		gdb -q -nx -batch -x probes/suite.py "$binary" >"$log" 2>&1 || true

	line=$(grep -m1 '^PROBE_RESULT ' "$log" || true)
	if [ -z "$line" ]; then
		echo "  no result — gdb output follows:" >&2
		tail -20 "$log" >&2
		printf '{"group":"%s","target":"%s","results":{}}\n' "$group" "$name" >> "$raw"
		return 0
	fi
	printf '{"group":"%s","target":"%s","results":%s}\n' \
		"$group" "$name" "${line#PROBE_RESULT }" >> "$raw"
}

echo "--- probes"
probe symbols       fixtures/programs/scalars.odin
probe values        probes/targets/values.odin
probe frames        fixtures/programs/fibonacci.odin
probe simple-return fixtures/programs/simple-call.odin
probe threads       fixtures/programs/spawns-thread.odin
probe no-debug-info fixtures/programs/scalars.odin --no-debug

# step-cost is recorded at three sizes (ROADMAP Phase 0, acceptance 3).
probe confined      fixtures/programs/scalars.odin
probe confined      fixtures/programs/fibonacci.odin
probe confined      fixtures/programs/long-trace.odin

echo "--- report"
python3 probes/report.py "$raw" "$out"
echo "wrote $out"

python3 - "$raw" <<'PY'
import json, sys

BLOCKING = {"entry-symbol", "line-table", "struct-fields", "slice-fields"}
failed = []
for line in open(sys.argv[1], encoding="utf-8"):
    entry = json.loads(line)
    for name, result in entry["results"].items():
        if name in BLOCKING and not result["ok"]:
            failed.append(name)

if failed:
    print()
    print("BLOCKING probes failed: " + ", ".join(sorted(set(failed))))
    print("ROADMAP Phase 0: do not proceed with a plan to work around this.")
    print("Reopen ADR-004 and ADR-002, and treat the native adapter as the")
    print("primary path rather than an optional one. That is a different")
    print("project with a different cost, and it deserves a decision.")
    sys.exit(1)

print()
print("all BLOCKING probes passed")
PY
