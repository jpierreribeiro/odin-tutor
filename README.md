# odin-tutor

A local terminal tool that teaches the Odin programming language. It makes
program execution and memory behaviour visible.

The student runs an exercise. The tool compiles it, executes it once under a
debugger, and records a bounded trace. The student then moves forward and
backward through that trace in a terminal user interface, and sees the call
stack, the variables, and the object graph at each step.

## Status

**Phases 0 through 3 complete.** One command takes a `.odin` file to a rendered
step, and the picture it draws is the memory model: identities that are never
addresses, sub-slices shown as windows onto one buffer, pointers resolved to
references, cycles that show their own identifier, and return values attributed
to the invocation that produced them. `./check.sh` passes — `-vet -strict-style`
clean, 51 tests across five packages, both JSON schemas validating the real
adapter output — and every acceptance criterion of Phases 1, 2 and 3 is checked
by a script anyone can run.

`fib(6)` shows **25 return values and not one that contradicts its frame**.
Frame identity was the least validated part of the design; it now has evidence
at depth 100.

```sh
export ODIN_ROOT=/path/to/Odin        # core: imports fail without it
./check.sh                            # is the code correct?
./probes/run.sh                       # does this toolchain work?
./tests/phase1-acceptance.sh          # is the phase done?
./tests/phase2-acceptance.sh
./tests/phase3-acceptance.sh

./odin-tutor trace fixtures/programs/sub-slice.odin trace.json
./odin-tutor render trace.json 4
```

```
OBJECTS
  #2 struct []int (3)  [shares storage @3]
      [0] = 7
      [1] = 8
      [2] = 9
  #4 struct []int (2)  [shares storage @3]
      [0] = 8
      [1] = 9
```

Two views, one buffer. `#2` and `#4` are identities, not addresses — trace the
same program again with address randomisation on and they are the same two
numbers.

`trace` runs preflight, compiles with a cache keyed by source **and** Odin
version, drives gdb, records the observation stream beside the trace, and
assembles it. The recorded stream replays to a byte-identical trace with gdb
uninstalled, which is what makes every later phase testable in milliseconds.

Not built yet: the interactive step player (Phase 4), the validator and the
exercises (Phase 5).
See [`docs/ROADMAP.md`](docs/ROADMAP.md).

Read [`docs/PROJECT.md`](docs/PROJECT.md) first, then
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

A first Phase 0 probe run took place on **2026-08-05** against Odin
`dev-2026-08:9caff63` and GNU gdb 15.1 on Ubuntu 24.04 x86-64. Report:
[`fixtures/toolchain/2026-08-05-linux-x86_64.md`](fixtures/toolchain/2026-08-05-linux-x86_64.md).

| | |
|---|---|
| Closed by evidence | R-01, R-02, R-03, R-04, R-05, R-08, R-17, R-18 |
| Landed; mitigation measured and required | R-19 — stepping is **not** confined to the student's source |
| Opened by the probes | R-20 map entries unreadable ([decided](docs/decisions/ADR-014-maps-are-counted-not-walked.md)) · R-21 use-after-free undetectable by reading · R-22 `= ---` undetectable by reading |
| Measured | 1.31 ms per student step · 0.98 s to compile |

The headline result: **`fib(6)` produced 25 invocations, 25 return values, and
zero wrong values.** Frame identity under recursion was the least validated part
of the design. It now has evidence.

A second pass found **three assumptions about Odin that were wrong**, including
one — detecting a second thread by counting threads — that would have shipped a
safeguard that never fires. They are in Part 2 of the report.

The remaining unverified assumptions are in
[`docs/RISKS.md`](docs/RISKS.md), and what the project still cannot claim is in
[`docs/REVIEW.md`](docs/REVIEW.md) §10.

## Document map

Read in this order.

| Document | Question it answers |
|---|---|
| [PROJECT.md](docs/PROJECT.md) | Why does this exist? What is out of scope? |
| [GLOSSARY.md](docs/GLOSSARY.md) | What does each term mean? Terms are used exactly. |
| [REQUIREMENTS.md](docs/REQUIREMENTS.md) | What must the system do? (`REQ-*`) |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How are the parts arranged? What is written in Odin? |
| [DOMAIN-MODEL.md](docs/DOMAIN-MODEL.md) | What entities exist? |
| [MEMORY-MODEL.md](docs/MEMORY-MODEL.md) | What is object identity? (`SPEC-MEM-*`) |
| [TRACE-SPEC.md](docs/TRACE-SPEC.md) | What is the trace format? (`SPEC-TRACE-*`) |
| [OBSERVATION-SPEC.md](docs/OBSERVATION-SPEC.md) | What does the adapter emit? (`SPEC-OBS-*`) |
| [DEBUGGER-ADAPTER.md](docs/DEBUGGER-ADAPTER.md) | How is the debugger driven? (`SPEC-ADP-*`) |
| [PLATFORM-SUPPORT.md](docs/PLATFORM-SUPPORT.md) | Which platforms work? |
| [TUI-SPEC.md](docs/TUI-SPEC.md) | What does the screen show? (`SPEC-TUI-*`) |
| [EXERCISE-SPEC.md](docs/EXERCISE-SPEC.md) | What is an exercise? (`SPEC-EX-*`) |
| [VALIDATION-SPEC.md](docs/VALIDATION-SPEC.md) | How is an exercise checked? (`SPEC-VAL-*`) |
| [SAFETY.md](docs/SAFETY.md) | How does the tracer defend itself? (`SPEC-SAFE-*`) |
| [PERFORMANCE.md](docs/PERFORMANCE.md) | What are the budgets? (`SPEC-PERF-*`) |
| [TEST-STRATEGY.md](docs/TEST-STRATEGY.md) | How is correctness tested? |
| [QUALITY-GATES.md](docs/QUALITY-GATES.md) | When is work complete? |
| [AGENT-GUIDE.md](docs/AGENT-GUIDE.md) | Rules for any agent that changes this repository. |
| [ROADMAP.md](docs/ROADMAP.md) | What order is the work done in? |
| [RISKS.md](docs/RISKS.md) | What can go wrong? What is unverified? |
| [REVIEW.md](docs/REVIEW.md) | Where do these documents still disagree with each other? |
| [TRACEABILITY.md](docs/TRACEABILITY.md) | Requirement → spec → test. |
| [CURRICULUM.md](docs/CURRICULUM.md) | What order do the exercises teach in? |
| [decisions/](docs/decisions/) | Architecture decision records (`ADR-*`). |
| [ADR-013](docs/decisions/ADR-013-odin-conventions.md) | **How is the Odin written?** Read before touching `src/`. |
| [ADR-014](docs/decisions/ADR-014-maps-are-counted-not-walked.md) | Why a map shows a count and no entries. |

## The one rule that outranks the others

**Unknown is better than false.**

This tool draws pictures of memory. A picture that is wrong but believable is
worse than no picture, because the student learns the wrong thing and has no
signal that anything failed. If the system cannot determine a value, an
identity, or a relationship, it must report that state. It must not guess.

See [ADR-008](docs/decisions/ADR-008-unknown-over-false.md).
