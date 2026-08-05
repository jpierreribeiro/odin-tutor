# PERFORMANCE

Budgets, and the one performance rule that is architectural.

---

## 1. The rule that outranks the numbers

<a id="spec-perf-001"></a>
### SPEC-PERF-001 — Navigation never re-executes
Moving to any step reads the trace. It does not run the target program, does not
run the compiler, and does not start a debugger.
[REQ-TRACE-001](REQUIREMENTS.md#req-trace-001).

This is not an optimisation. It is what makes backward navigation possible at
all, and it is why the trace exists as an artefact rather than as a live
debugger session.

---

## 2. Where time goes

Partly measured. The 2026-08-05 probe run
([report](../fixtures/toolchain/2026-08-05-linux-x86_64.md)) replaced the two
rows that were guesses.

| Phase | Share | Bounded by |
|---|---|---|
| Preflight | negligible | — |
| Compile | **0.98 s median** for a single file with `-debug`, measured | the compiler |
| Trace generation | **1.31 ms per student step, measured** | `wall_ms`, `steps` |
| Trace assembly (core) | small | must be linear, §4 |
| Navigation | negligible | §3 |

**The expectation was wrong, in the good direction.** This document assumed trace
generation would dominate. At 1.31 ms per step, a 300-step exercise traces in
about 0.4 s and the whole 2500-step limit in about 3.3 s. **Compilation
dominates** at every size an exercise will reach: ~1 s to compile against ~0.4 s
to trace.

Two things make the measured cost that low. `finish` leaves a runtime call in
one operation rather than stepping through it
([SPEC-ADP-014](DEBUGGER-ADAPTER.md#spec-adp-014)), and the budgets keep the
per-stop read small.

This does not remove the budgets. It means they now bound a runaway rather than
an ordinary run, which is what
[ADR-006](decisions/ADR-006-budgets.md) says a budget is for.

---

## 3. Budgets

<a id="spec-perf-010"></a>
### SPEC-PERF-010 — Navigation latency
Moving to any step, including a jump to an arbitrary index, completes in
**under 16 ms** at the 99th percentile on the largest fixture.

*Rationale:* 16 ms is one frame at 60 Hz. Below it, navigation feels immediate.
The keyframe interval is chosen so that this holds
([SPEC-TRACE-001](TRACE-SPEC.md#spec-trace-001)): a jump applies at most 31
deltas of a small object.

<a id="spec-perf-011"></a>
### SPEC-PERF-011 — Startup
From process start to the first rendered step, for a cached build:
**under 200 ms**.

<a id="spec-perf-012"></a>
### SPEC-PERF-012 — Trace generation
For a reference exercise of about 300 steps: **under 10 s** wall time.

The hard limit is `wall_ms` = 60 000 ([SAFETY.md](SAFETY.md) §4). The 10 s figure
is the target for an exercise to be usable in a loop where the student edits and
re-runs.

An exercise whose reference solution exceeds 10 s is too large
([SPEC-EX-051](EXERCISE-SPEC.md#spec-ex-051)).

<a id="spec-perf-013"></a>
### SPEC-PERF-013 — Memory
Peak resident memory of the tool, excluding the debugger and the target:
**under 256 MiB** for the largest fixture.

The trace itself is bounded by `trace_bytes` = 32 MiB. Materialised steps are
not all held at once: the consumer holds the current step and at most one
keyframe interval of deltas.

<a id="spec-perf-014"></a>
### SPEC-PERF-014 — Trace size
A trace for a 300-step exercise: **under 2 MiB** at `K = 32`.

---

## 4. Complexity requirements

These are requirements, not aspirations. Each exists because the natural
implementation is the wrong one.

<a id="spec-perf-020"></a>
### SPEC-PERF-020 — Trace assembly is linear in steps
Assembly cost grows linearly in the number of steps.
[REQ-PERF-002](REQUIREMENTS.md#req-perf-002).

**The trap.** A size check that serialises the accumulated document at every
step is O(n²). A prior system did this and measured, for the size check alone:
2.0 s at 533 steps and 46.7 s at 2500 steps, inside a 15 s budget. The
consequence was not slowness: the step limit became **unreachable**, so a long
trace always failed by timeout inside the measuring code, and the student
received an error where a partial trace was correct.

*Rule:* measure the new step, accumulate the number. Never re-measure the whole.

A benchmark at 100, 400, and 1600 steps asserts the growth ratio.

<a id="spec-perf-021"></a>
### SPEC-PERF-021 — Pointer expansion is bounded per trace, not only per step
Expansion cost is steps × expansions per step. A per-step bound alone leaves the
product unbounded. A prior system measured a linked structure at 20 nodes in
1.7 s, 40 in 3.4 s, 80 in 12 s, and 150 as a timeout, with a per-step bound in
place.

Both bounds exist ([SAFETY.md](SAFETY.md) §4). When the trace-wide budget is
exhausted, pointers stop being expanded and remain pointer values. The trace
completes.

*Rationale for that degradation:* a trace that completes without some structure
drawn is worth more than no trace. The student keeps the step player.

<a id="spec-perf-022"></a>
### SPEC-PERF-022 — Materialisation is bounded by the keyframe interval
Materialising step *n* applies at most `K - 1` deltas. It never replays from
step 0.

<a id="spec-perf-023"></a>
### SPEC-PERF-023 — Identity assignment is amortised constant per entity
The identity map is a hash table keyed by the tuples in
[SPEC-MEM-002](MEMORY-MODEL.md#spec-mem-002). Assignment does not scan.

<a id="spec-perf-024"></a>
### SPEC-PERF-024 — The reachable set is computed once per step
Each step computes its reachable entities in one traversal, with a visited set.
A cyclic graph terminates ([REQ-MEM-011](REQUIREMENTS.md#req-mem-011)).

---

## 5. Measurement

<a id="spec-perf-030"></a>
### SPEC-PERF-030 — Benchmarks are fixtures, not ad-hoc programs
Performance is measured on the fixture set, so a number is comparable between
commits.

<a id="spec-perf-031"></a>
### SPEC-PERF-031 — Two numbers are recorded per run
The run report records wall time for trace generation and for assembly,
separately. Combining them hides which one regressed.

<a id="spec-perf-032"></a>
### SPEC-PERF-032 — A budget change requires a measurement
Changing a default in [SAFETY.md](SAFETY.md) §4 requires a recorded measurement
in the pull request. A budget chosen by intuition is how the quadratic size
check survived.

---

## 6. What is not optimised

- **Trace generation speed.** It is bounded, not minimised. Making the debugger
  faster is not this project's work.
- **Compilation.** The compiler is what it is. The build is cached by source
  hash and toolchain version; nothing more.
- **Trace size on disk.** It is local. Below the byte budget, smaller is not
  better if it costs clarity. The keyframe interval trades size for random
  access on purpose.
