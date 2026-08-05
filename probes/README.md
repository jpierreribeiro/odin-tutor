# The probe suite

Answers **"does this toolchain work?"** — separately from `check.sh`, which
answers "is this code correct?".

```sh
export ODIN_ROOT=/path/to/Odin
./probes/run.sh                      # writes fixtures/toolchain/<date>-<os>-<arch>.md
./probes/run.sh --out <path>         # writes it somewhere else
```

The suite refuses to overwrite an existing report. A committed report is
evidence for a row in the compatibility table, and silently replacing evidence
is how a claim outlives the run that justified it.

**Exit code:** 0 unless a BLOCKING probe failed. A HIGH or MEDIUM failure is a
recorded fact about the platform, not a broken build
([SPEC-TEST-042](../docs/TEST-STRATEGY.md#spec-test-042)).

## Why it exists

[SPEC-PLAT-031](../docs/PLATFORM-SUPPORT.md#spec-plat-031): a row is added to the
compatibility table only when this suite passes on that combination and its
report is committed.

The tool's correctness depends on the quality of the debug information a
specific compiler version emits. That is not a constant. Treating the toolchain
as a fixed background is how a tool silently starts lying after a routine
update.

## What is here

| File | What it is |
|---|---|
| `run.sh` | The driver. Builds each target, runs one gdb per probe group, writes the report. |
| `suite.py` | The probes. Runs inside gdb's Python interpreter, one group per invocation, selected by `$PROBE`. |
| `report.py` | Turns the collected results into the Markdown report. |
| `targets/values.odin` | The one target that is not a student fixture. |

Most probes run against the real fixtures in
[`../fixtures/programs/`](../fixtures/programs/), which is the point of having
them. `targets/values.odin` exists because a probe target and a student fixture
have opposite jobs: a fixture isolates one thing, a probe target deliberately
combines several so one gdb run can answer several questions. It also carries
the map, because [TEST-STRATEGY.md](../docs/TEST-STRATEGY.md) §5 lists no map
fixture and adding one would be inventing a requirement.

## The probes

[SPEC-TEST-041](../docs/TEST-STRATEGY.md#spec-test-041). Four are BLOCKING: if
they fail on every combination tried, ROADMAP Phase 0 says **stop**, not work
around it.

| Group | Target | Probes |
|---|---|---|
| `symbols` | `scalars` | entry-symbol, line-table, thread-count, free-symbol, only-student-code |
| `values` | `targets/values` | struct-fields, slice-fields, string-value, map-entries |
| `frames` | `fibonacci` | frame-key, frame-key-spread, finish-breakpoint |
| `simple-return` | `simple-call` | simple-return |
| `threads` | `spawns-thread` | thread-event, thread-count-is-unsound |
| `no-debug-info` | `scalars`, stripped | no-debug-info |
| `confined` | `scalars`, `fibonacci`, `long-trace` | confined-stepping, step-cost at three sizes |

### Two probes are expected to fail

`only-student-code` and `map-entries`. Both are known, both are recorded as
expected in the report, and both have a documented consequence
([SPEC-ADP-014](../docs/DEBUGGER-ADAPTER.md), [R-20](../docs/RISKS.md#r-20)). An
expected failure that reads like a surprise teaches the next reader the wrong
thing, so the report marks them.

## The traps this suite encodes

Every one of these cost time on 2026-08-05, and every one produces a wrong
answer rather than an error.

**The entry symbol is `main::main`, with a double colon.** `main.main` does not
resolve at all.

**A `FinishBreakpoint` whose `stop()` returns `True`**, on a recursive procedure
that also carries an ordinary breakpoint, never fires as expected — the deeper
call's breakpoint interleaves first. The first reading of that was "return
values are not observable". They are. Return `False`.

**Counting threads at each stop detects nothing.** A thread can be created and
exit between two stops, and one did. Only `gdb.events.new_thread` catches it,
ignoring thread number 1. A safeguard built on the count would never fire, which
is worse than having none: its presence implies protection.

**Stepping is not confined to the student's source.** The mitigation is to
`finish` out of any frame whose source file is not the student's
(SPEC-ADP-014). Without it, most stops land in the runtime or in glibc.

**Breakpoints stay live during `next`.** The `frame-key` probe disables them
before stepping, or gdb stops inside a deeper recursive invocation and the
second reading describes a different frame — which looks exactly like a key that
is not stable.

**A line number in a probe goes stale the moment its target is edited.**
`suite.py` finds its breakpoint by searching for a `PROBE-BREAK` marker instead,
because a stale breakpoint makes a probe report a failure that is not one.
