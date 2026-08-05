# Reproducing the probe run

These are the throwaway scripts from the 2026-08-05 run, kept because a claim in
[PLATFORM-SUPPORT.md](../../docs/PLATFORM-SUPPORT.md) §5 is only as good as the
evidence beside it.

They are **not** the probe suite. The probe suite
([SPEC-TEST-041](../../docs/TEST-STRATEGY.md#spec-test-041)) now exists at
[`probes/`](../../probes/): repeatable, exit-coded, and emitting the report
rather than being read by a human. Run that, not these.

These scripts are what it was built from, and they are kept because the claim in
[PLATFORM-SUPPORT.md](../../docs/PLATFORM-SUPPORT.md) §5 for the
`dev-2026-08:9caff63` row rests on this run rather than on the suite. Deleting
them would leave that row without its evidence.

## Environment

Ubuntu 24.04, x86-64. No Odin needed to start — it is built from source.

```sh
apt-get install -y --no-install-recommends llvm-18-dev clang-18 gdb
git clone --depth 1 https://github.com/odin-lang/Odin.git
cd Odin && ./build_odin.sh release
export ODIN_ROOT=$PWD          # required: without it, core: imports fail
export PATH=$ODIN_ROOT:$PATH
```

`ODIN_ROOT` is not optional when running a compiler that was not installed to a
standard prefix. Without it, `import "core:fmt"` fails with a path error that
does not mention the variable.

Confirm the debugger has Python before anything else:

```sh
gdb --configuration | grep python
```

## The scripts

| File | What it answers |
|---|---|
| `fixture.odin` | The target for the first pass: struct, slice, sub-slice, string, recursion, allocation |
| `probe.py` | entry symbol, thread count, free symbol, line table, stepping confinement, step cost |
| `probe2.py` | struct fields, slice fields, string value, frame key, return value |
| `probe3.py` | why `return_value` looked absent; which files stepping leaks into |
| `probe4.py` | return value on a non-recursive procedure, in isolation |
| `probe5.py` | **the frame-key result**: 25 invocations of `fib(6)`, attribution, call sites |
| `probe6.py` | the confined stepping loop, measured |
| `antilie.odin` + `antilie.py` | every observation the anti-lie fixtures need |
| `threadfix.odin` + `probe7.py`, `probe8.py` | thread detection by counting — **it does not work** |
| `probe9.py`, `probe10.py` | thread detection by event — it does |
| `os2probe.odin` | driving `gdb` from Odin through a pipe |

Run one:

```sh
odin build fixture.odin -file -debug -out:fixture
gdb -q -nx -batch -x probe5.py ./fixture
```

## Two traps that cost time in this run

**A `FinishBreakpoint` whose `stop()` returns `True`** on a recursive procedure
that also carries an ordinary breakpoint does not fire as expected: the deeper
call's breakpoint interleaves first. The first reading of that was "return
values are not observable". They are. Return `False`.

**Counting threads at each stop** detects nothing. A thread can be created and
exit between two stops, and this one did. Use `gdb.events.new_thread`, and
ignore thread number 1.
