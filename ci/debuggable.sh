#!/bin/sh
# Can this machine run a debugger at all?
#
#   ./ci/debuggable.sh
#
# Nothing here touches this project's code. That is the point: when a trace
# fails, the first question is whether the machine allows one process to control
# another, and the answer must not depend on the tool being correct.
#
# It is the first job in CI for the same reason. A red X here means the runner
# cannot do what the tool needs; a red X anywhere else means the tool is wrong.
# Those two answers must never arrive on the same line.
set -e

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "--- gdb is present, and was built with Python"
# The reader runs INSIDE gdb (ADR-004). A gdb without Python cannot load it, and
# the failure that produces is confusing enough to be worth its own check.
gdb --version | head -1
gdb -batch -ex 'python print("gdb has python")' | grep -q 'gdb has python'
echo "ok"

echo
echo "--- one process can control another"
cat > "$work/t.c" <<'C'
int main(void) { return 0; }
C
cc -g -o "$work/t" "$work/t.c"

# STOPPING a child and reading its state, not merely running it to completion —
# a program that runs to the end proves nothing, because that is what happens
# when the debugger controls nothing at all.
#
# Yama's ptrace_scope=1 still permits this, which is all this tool ever does: it
# never attaches to a process it did not start. A sandbox that forbids even that
# is the case this check exists to name.
if gdb -batch -ex 'break main' -ex run -ex 'info registers rip' -ex kill "$work/t" \
	> "$work/out" 2>&1; then
	grep -q 'rip' "$work/out" && echo "ok: gdb stopped a program and read its registers"
else
	echo "FAILED: gdb could not run a program here." >&2
	echo >&2
	sed 's/^/    /' "$work/out" >&2
	echo >&2
	echo "    ptrace_scope: $(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo 'not present')" >&2
	echo "    This machine cannot be used for tracing until that is resolved." >&2
	exit 1
fi

echo
echo "this machine can be traced on"
