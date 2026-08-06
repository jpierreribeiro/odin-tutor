# RISKS

What is not known, and what could go wrong.

This document has two parts. §2 classifies the **unknowns**: questions whose
answers are not in evidence yet. §3 is the **risk register**: each unknown, plus
the risks that are not unknowns, with probability, impact, mitigation, and the
validation that closes them.

Both parts use one set of identifiers, `R-nn`, so a reference from another
document points at one thing.

---

## 1. How an item is classified

| Class | Meaning |
|---|---|
| **BLOCKING** | If the answer is bad, the project as specified is not possible. Work on the affected component must not start before the answer exists. |
| **HIGH** | If the answer is bad, a stated requirement cannot be met and must be restated as a limit. The project continues. |
| **MEDIUM** | If the answer is bad, quality or scope suffers. Work continues with a known cost. |
| **LOW** | Worth recording. No plan changes today. |

The classification is about **consequence**, not about likelihood. A BLOCKING
item can be unlikely. Likelihood belongs in §3.

### The rule that gives this document its purpose
> No BLOCKING item may be closed by reasoning. Each is closed by a probe that
> runs against a real toolchain and commits its report.

Every BLOCKING item below is answered by [ROADMAP.md](ROADMAP.md) Phase 0, and
Phase 0 exists for no other reason.

---

## 2. Critical unknowns

### BLOCKING

| ID | The question | Where it bites |
|---|---|---|
| **R-01** | Does the pinned Odin version emit debug information good enough for the debugger to resolve the student's entry procedure and step the line table in source order? | Everything. No trace exists without it. |
| **R-02** | Are struct fields, and the `{data, len}` interior of a slice and a string, readable through the debugger's typed value interface? | [MEMORY-MODEL.md](MEMORY-MODEL.md) §8. Without it the picture shows scalars only, which is not the product. |
| **R-03** | Is GDB, built with Python, available on the target platform in a form a student can install? | [ADR-004](decisions/ADR-004-in-debugger-extractor.md). Without Python inside GDB the whole extractor design is void. |

### HIGH

| ID | The question | Where it bites |
|---|---|---|
| **R-04** | Can the adapter read the caller's program counter and stack pointer at depth ≥ 2, and are both stable within one invocation? | [SPEC-MEM-060](MEMORY-MODEL.md#spec-mem-060). This is the frame key. Without it, recursion has no reliable frame identity. |
| **R-05** | Is a return value observable, and attributable to the invocation that produced it? | [REQ-FRAME-003](REQUIREMENTS.md#req-frame-003). Without it, return values are withheld everywhere. |
| **R-06** | What does one step cost in wall time on a real target? | [SAFETY.md](SAFETY.md) §4 `wall_ms`, and whether a 300-step exercise fits in 10 s. |
| **R-07** | Can allocation identity survive address reuse without observing the allocator? | [SPEC-MEM-042](MEMORY-MODEL.md#spec-mem-042). The answer is already known to be **no** for one case. |

### MEDIUM

| ID | The question | Where it bites |
|---|---|---|
| **R-08** | Can Odin drive an external process with pipes? | ~~[ADR-002](decisions/ADR-002-implementation-language.md)~~ **Closed 2026-08-05.** Yes, through `core:os`. The package `core:os/os2` named in the plan **no longer exists**. |
| **R-09** | Does trace assembly stay linear in the number of steps once the byte budget is enforced? | [SPEC-PERF-020](PERFORMANCE.md#spec-perf-020). The natural implementation is quadratic. |
| **R-10** | Does the student's program's output interleave correctly with the steps? | [REQ-TRACE-006](REQUIREMENTS.md#req-trace-006). A prior system reported zero output at every step. |
| **R-11** | Is the terminal baseline in [ADR-010](decisions/ADR-010-no-tui-framework.md) honoured widely enough? | [TUI-SPEC.md](TUI-SPEC.md) §6. |
| **R-12** | Can exercises be authored at a rate that makes the tool a course rather than a demonstration? | [EXERCISE-SPEC.md](EXERCISE-SPEC.md). |
| **R-13** | On macOS, does an LLDB adapter produce the same trace, and can a student grant the debugger the rights it needs? | [PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md) §3. |

### LOW

| ID | The question | Where it bites |
|---|---|---|
| **R-14** | Will the trace format need a breaking change before version 1 ships? | [SPEC-TRACE-072](TRACE-SPEC.md#spec-trace-072). |
| **R-15** | Will the direct ANSI code accumulate per-terminal special cases? | [ADR-010](decisions/ADR-010-no-tui-framework.md) validation. |
| **R-16** | Will Odin language or core library changes break this project's own source? | The build. **Already demonstrated:** `core:os/os2` no longer exists. |

### Added after the probe runs

| ID | The question | Class | Where it bites |
|---|---|---|---|
| **R-20** | Can map entries be read at all through the debugger? | **HIGH** | [MEMORY-MODEL.md](MEMORY-MODEL.md) §8 assumed yes. The type exposes only `['data', 'len', 'allocator']` — no key or value access. |
| **R-21** | Can use-after-free be detected by reading? | **Answered: no.** | A freed region stays mapped and returns plausible garbage with no error. Phase 6 is the only mechanism. |

### Added after the consistency review

| ID | The question | Class | Where it bites |
|---|---|---|---|
| **R-17** | Does a plain single-threaded Odin program actually run one thread under the debugger, or does the runtime start helpers? | **HIGH** | [ADR-012](decisions/ADR-012-single-threaded-target.md). If the runtime spawns a thread, the detection rule ends every trace immediately and the tool is unusable until the rule is refined. |
| **R-18** | Does the default Odin allocator have a breakpoint-able free path? | MEDIUM | [ROADMAP.md](ROADMAP.md) Phase 6a. If not, closing [R-07](#r-07) costs full allocation observation instead of a cheap subset. |
| **R-19** | Can the debugger be confined to the student's source, or does stepping descend into the runtime? | **HIGH** | [REQ-FRAME-001](REQUIREMENTS.md#req-frame-001). Found by the review with no probe and no fallback. Probe added; not run. |

---

## 3. Risk register

Probability and impact are stated for the **version 1 timeframe**.
Impact is: what the student experiences if the risk lands.

### Status after the 2026-08-05 probe run
Phase 0 ran on Odin `dev-2026-08:9caff63` with gdb 15.1 on Ubuntu 24.04 x86-64.
Report: [`fixtures/toolchain/2026-08-05-linux-x86_64.md`](../fixtures/toolchain/2026-08-05-linux-x86_64.md).

| | Items |
|---|---|
| **Closed by evidence** | R-01, R-02, R-03, R-04, R-05, R-17, R-18 |
| **Landed, mitigation measured** | R-19 |
| **Measured, no longer a guess** | R-06 |
| **Still open** | R-07 (by design), R-09, R-10, R-11, R-12, R-13, R-14, R-15, R-16 |
| **Opened by the second pass** | R-20 (maps unreadable), R-21 (use-after-free undetectable by reading) |

The second pass also closed R-08 and corrected three things the specification
had wrong. See Part 2 of the report.

A closed item stays in this document. It is closed **on one combination**, and
[ADR-009](decisions/ADR-009-toolchain-pinning.md) exists because that is not the
same as closed forever.

---

<a id="r-01"></a>
### R-01 — Debug information is not usable on the pinned toolchain
**Class:** BLOCKING · **Status: CLOSED on the pinned combination, 2026-08-05**

**Measured.** `entry-symbol`, `line-table`, `struct-fields`, and `slice-fields`
all pass. The entry procedure resolves as `main::main`; stepping visits student
lines in source order.

Two prior beliefs in this document were **wrong** and are corrected here:

| Was written | Measured |
|---|---|
| "Odin emits DWARF version 3" | This version emits **DWARF 4** |
| The entry symbol was assumed to be `main.main` | It is **`main::main`** |

The community reports of poor GDB support describe some period, not this one.
The risk was real; the answer on this combination is good.

**Mitigation:** [ADR-009](decisions/ADR-009-toolchain-pinning.md) — pin one
combination, detect versions at runtime, keep an evidence-backed table. If the
first combination probed fails, probe another; the project supports a
combination, not a version range.

**Validation:** Phase 0 probes `entry-symbol`, `line-table`, `struct-fields`,
`slice-fields` ([SPEC-TEST-041](TEST-STRATEGY.md#spec-test-041)). A committed
report under `fixtures/toolchain/` closes this.

**If it lands:** no combination of Odin and GDB supports the model. The project
is not possible as specified. The next option is a native adapter reading DWARF
directly ([ROADMAP.md](ROADMAP.md) Phase 7 brought forward), which is a much
larger project and would need its own decision.

---

<a id="r-02"></a>
### R-02 — Composite types are opaque through the debugger
**Class:** BLOCKING · **Status: CLOSED, 2026-08-05**

**Measured.** A slice exposes `{data, len}`; elements are read through the data
pointer cast to an array of the element type. `notas` read as `[7, 8, 9]`.
A string read as `"Ana"`. A struct exposed `['nome', 'notas', 'idade']`.

The result that matters most: `sub := notas[1:]` produced `len = 2` and a `data`
pointer **8 bytes past** the parent's. Shared storage is detectable from the
observation alone, so [REQ-MEM-005](REQUIREMENTS.md#req-mem-005) is reachable
without any extra mechanism.

A slice is a struct of a data pointer and a length. If the debugger exposes the
struct but the project cannot read the pointer's target as an array of the
element type, slices render as two numbers.

**Mitigation:** the adapter reads the fields and performs the element read
itself, bounded by [SPEC-SAFE-010](SAFETY.md#spec-safe-010). This is within the
Python API's documented capability.

**Validation:** the `slice-fields` probe, plus the `slice-of-int`, `sub-slice`,
and `two-empty-slices` fixtures.

**If it lands:** the memory picture degrades to scalars and pointer values. The
tool still teaches control flow and frames. It does not teach the thing it
exists to teach.

---

<a id="r-03"></a>
### R-03 — GDB without Python
**Class:** BLOCKING · **Status: CLOSED for the reference platform, 2026-08-05**

Ubuntu 24.04's stock `gdb` 15.1 reports `--with-python`. The whole extractor
design runs on it. This stays a risk **per machine**, not per project: another
distribution may still ship GDB without Python, and preflight still checks.

Some distributions ship a GDB built without Python.

**Mitigation:** preflight runs `gdb --configuration` and fails with a named
error and an installation instruction, before compiling anything.
[SPEC-ADP-004](DEBUGGER-ADAPTER.md#spec-adp-004).

**Validation:** a preflight test with a stubbed `gdb` that reports no Python.

**If it lands on many machines:** the fallback is GDB/MI over a pipe
([ADR-004](decisions/ADR-004-in-debugger-extractor.md) option A), which cannot
validate a length before it sizes a read. That would be a documented reduction
in safety, not a drop-in replacement.

---

<a id="r-04"></a>
### R-04 — The frame key is not available or not stable
**Class:** HIGH · **Probability:** medium · **Impact:** high

The frame key is the caller's program counter plus the caller's stack pointer
([SPEC-MEM-060](MEMORY-MODEL.md#spec-mem-060)). It exists to tell two
invocations apart when stack depth cannot, which is the case for two calls on
one source line.

**Status: CLOSED, 2026-08-05.** This was the least validated part of the design.
It has now run against a real debugger on a real Odin target.

`fib(6)` produced **25 invocations, 25 observed return values, 0 out of scope,
and 0 wrong values.** The caller's `(pc, sp)` was stable across a step within one
invocation, at depth 7.

The load-bearing detail held: `fib(n-1) + fib(n-2)` occupies one source line and
produced **two different return addresses**, so the two sibling calls are
distinguishable. Three distinct call sites, eleven distinct frame keys, five
stack pointers per recursive site.

The original rule was designed from a measured failure in another system — a
frame holding `n = 0` reported that it returned 8. The design that replaced it
now has evidence, not just a rationale.

**Mitigation, in order:**
1. Phase 0 `frame-key` probe, at depth ≥ 2, checking stability across steps.
2. [SPEC-MEM-061](MEMORY-MODEL.md#spec-mem-061) is the floor: when the identity
   cannot be determined, the return value is withheld. The picture loses
   information; it never gains a wrong value.
3. If the key is unstable, the tool compiles the target with optimisation
   disabled and a frame pointer forced, and records that it did so.

**Validation:** the `frame-key` probe, plus the `fibonacci` and
`two-calls-one-line` fixtures, plus the property test in
[SPEC-TEST-022](TEST-STRATEGY.md#spec-test-022).

**If it lands:** return values are withheld for recursive programs, and
[REQ-FRAME-003](REQUIREMENTS.md#req-frame-003) is restated as a limit with a
test that asserts the withholding
([SPEC-GATE-010](QUALITY-GATES.md#spec-gate-010)).

---

<a id="r-05"></a>
### R-05 — Return values are not observable or not attributable
**Class:** HIGH · **Status: CLOSED, 2026-08-05**

`FinishBreakpoint.return_value` works. One interaction is worth carrying into
the implementation: on a recursive procedure that also has an ordinary
breakpoint, a `FinishBreakpoint` whose `stop()` returns `True` does not fire as
expected, because the deeper call's ordinary breakpoint interleaves first.
Returning `False` gives all 25 values correctly.

A first attempt at this probe read that interaction as "return values are not
observable". They are. The lesson is recorded because the wrong reading is the
natural one.

Distinct from R-04. R-04 is "which invocation". R-05 is "is there a value at
all". A return value in a register, at a point where the debugger considers the
frame already gone, may not be readable.

**Mitigation:** withhold. [SPEC-MEM-061](MEMORY-MODEL.md#spec-mem-061).

**Validation:** the `finish-breakpoint` probe. The pair of tests in
[SPEC-TEST-022](TEST-STRATEGY.md#spec-test-022): one forbids a wrong value, one
requires a value in the simple non-recursive case. The second test exists
because a prior system's "return never lies" check became vacuously true when
the code stopped emitting the values it inspected, and nothing noticed.

**If it lands:** no step shows a return value. The student sees the value at the
assignment on the next step instead. This is a real loss and a survivable one.

---

<a id="r-06"></a>
### R-06 — Tracing is too slow to use in an edit-and-run loop
**Class:** HIGH · **Status: MEASURED, 2026-08-05 — comfortably inside budget**

**1.31 ms per student step**, with the confinement mitigation in place.

| | |
|---|---|
| 300-step exercise | ≈ 0.4 s |
| 2500-step limit | ≈ 3.3 s |

Against a 10 s target and a 60 s hard limit. **Compilation, not tracing, is the
dominant cost** at this size, which inverts the expectation in
[PERFORMANCE.md](PERFORMANCE.md) §2.

The debugger stops the process at every line.
[SPEC-PERF-012](PERFORMANCE.md#spec-perf-012) targets 10 s for a 300-step
exercise; the hard limit is 60 s.

**Mitigation:**
- The budgets bound the worst case, so a slow toolchain produces a truncated
  trace rather than a hang ([ADR-006](decisions/ADR-006-budgets.md)).
- Exercises are sized so the reference solution stays under the target
  ([SPEC-EX-051](EXERCISE-SPEC.md#spec-ex-051)).
- The build is cached by source hash and toolchain version, so a re-run of
  unchanged source skips compilation.

**Validation:** the `step-cost` probe at three sizes, recorded in the
compatibility report.

**If it lands:** exercises become smaller, and the reference exercise size in
[PERFORMANCE.md](PERFORMANCE.md) §3 is revised downward with the measurement
attached.

---

<a id="r-07"></a>
### R-07 — A new object inherits a freed object's identity
**Class:** HIGH · **Probability:** **certain, in one specific case** ·
**Impact:** medium

This is not a risk in the usual sense. It is a **known incorrectness in version
1**, recorded here so it is not discovered later as a surprise.

When an allocation is freed, the allocator immediately returns the same address,
the new allocation has the same type, and the address never leaves the reachable
set, then the epoch rule
([SPEC-MEM-041](MEMORY-MODEL.md#spec-mem-041)) cannot distinguish them. The
picture reports a mutation where a death and a birth occurred.

What it does **not** do: fabricate a value, or expose an address.

**Mitigation in version 1:** the epoch rule catches the common cases — a type
change at the address, and an absence of at least one step **in a step that was
observed completely**. Documentation states the gap plainly.

**Widened by [ADR-011](decisions/ADR-011-absence-is-not-evidence.md).** An object
freed during a step that also truncated now keeps its identity, where before it
was caught by accident. That is the accepted cost of removing the opposite and
worse error: a display budget changing the identity of a living object. The two
errors were traded knowingly, not overlooked.

**Validation:** the `free-then-allocate` fixture asserts the *current, incorrect*
behaviour ([SPEC-TEST-021](TEST-STRATEGY.md#spec-test-021)). The test fails
loudly if the behaviour changes without
[REQ-MEM-003](REQUIREMENTS.md#req-mem-003) being met, in either direction.

**Closure path:** observe the allocator
([SPEC-MEM-043](MEMORY-MODEL.md#spec-mem-043)),
[ROADMAP.md](ROADMAP.md) Phase 6. Deferred because the Odin allocator is
selected through `context.allocator`, so there is no single fixed symbol to
break on, and because it multiplies debugger stops.

---

<a id="r-08"></a>
### R-08 — Odin cannot drive an external process with pipes
**Class:** MEDIUM · **Status: CLOSED, 2026-08-05**

An Odin program launched `gdb --version` through a pipe, read **293 bytes**, and
collected exit code 0. `os.process_start`, `os.pipe`, `os.read`, and
`os.process_wait` all work.

**The plan named a package that is gone.** `core:os/os2` was absorbed into
`core:os`. Every document that referenced `os2` has been corrected. This is the
clearest illustration of why [ADR-009](decisions/ADR-009-toolchain-pinning.md)
treats the toolchain as a versioned dependency: a plan written against a
remembered API had already expired.

**Mitigation:** the process launch is behind one small internal boundary. If
`os2` proves unstable, that boundary calls the platform directly. This is a
contained change, not an architecture change.

**Validation:** Phase 1 launches the debugger and reads its output. Failure is
visible immediately.

**If it lands:** a small amount of platform-specific Odin, or a foreign function
call. [ADR-002](decisions/ADR-002-implementation-language.md) already accepts
that "100% Odin" is a target, not a promise.

---

<a id="r-09"></a>
### R-09 — Trace assembly becomes quadratic
**Class:** MEDIUM · **Probability:** medium · **Impact:** high

The natural implementation of a byte budget re-serialises the accumulated
document at every step.

**This has already happened once, and the numbers are known:** 2.0 s at 533
steps and 46.7 s at 2500 steps for the size check alone, inside a 15 s budget.
The consequence was not slowness. The step limit became unreachable, so every
long trace failed by timeout inside the measuring code, and the student received
an error where a truncated trace was correct.

**Mitigation:** [SPEC-PERF-020](PERFORMANCE.md#spec-perf-020) — measure the new
step, accumulate the number, never re-measure the whole.
[ADR-006](decisions/ADR-006-budgets.md) records why.

**Validation:** a benchmark at 100, 400, and 1600 steps asserting the growth
ratio. It runs in continuous integration, not by hand, because this defect is
invisible on a small input.

---

<a id="r-10"></a>
### R-10 — Program output does not follow the steps
**Class:** MEDIUM · **Probability:** medium · **Impact:** medium

The student's program writes to standard output. The trace must record how much
output existed at each step, so the interface can show output as it appeared.

**This has already failed once:** a prior system reported zero bytes of output at
every step, and fixed the count only at the end of the run. Nothing noticed,
because the test checked only the final step, where the value was correct.

**Mitigation:** the adapter reads accumulated output length at each stop
([SPEC-OBS-031](OBSERVATION-SPEC.md#spec-obs-031)).

**Validation:** the `prints-in-loop` fixture asserts the **full sequence** of
output lengths across steps, not the last one. The `prints-utf8` fixture asserts
the count is in the same unit as the limit
([SPEC-TEST-030](TEST-STRATEGY.md#spec-test-030)).

---

<a id="r-11"></a>
### R-11 — Terminal diversity
**Class:** MEDIUM · **Probability:** low · **Impact:** low

**Mitigation:** a small ANSI subset ([ADR-010](decisions/ADR-010-no-tui-framework.md)),
plus configured ASCII and monochrome modes that lose no information
([SPEC-TUI-040](TUI-SPEC.md#spec-tui-040)).

**Validation:** golden tests read text, so they are terminal-independent by
construction. A manual check on three terminals per release.

---

<a id="r-12"></a>
### R-12 — Curriculum does not reach useful size
**Class:** MEDIUM · **Probability:** medium · **Impact:** high to the product,
none to the architecture

A tool with six exercises is a demonstration. The engineering can be complete
while the product is not.

**Mitigation:** the exercise format is data, with no code
([SPEC-EX-001](EXERCISE-SPEC.md#spec-ex-001)), so authoring does not require
touching the tool. The gate for a new exercise is four files and one rejected
wrong solution ([QUALITY-GATES.md](QUALITY-GATES.md) §3).

**Validation:** exercise count and the share of exercises whose assertions
reject at least one plausible wrong solution.

**Note:** this is the risk most likely to decide whether the project is *used*,
and the one least addressable by architecture. Recorded here so that is explicit.

---

<a id="r-13"></a>
### R-13 — macOS costs more than expected
**Class:** MEDIUM · **Probability:** medium · **Impact:** medium

macOS needs an LLDB adapter, and the debugger needs rights the operating system
restricts. Apple silicon adds an architecture whose frame key is not validated
([SPEC-PLAT-040](PLATFORM-SUPPORT.md#spec-plat-040)).

**Mitigation:** version 1 targets Linux. macOS is a later phase with its own
adapter and its own probe run, not a compatibility patch.

**Validation:** the same probe suite, on macOS, producing a matrix row.

---

<a id="r-14"></a>
### R-14 — A breaking trace format change before release
**Class:** LOW · **Probability:** medium · **Impact:** low

**Mitigation:** additive change is the default; a version increase requires an
ADR stating why additive was impossible
([SPEC-TRACE-072](TRACE-SPEC.md#spec-trace-072)). Fixtures at old versions are
kept.

**Validation:** the count of format versions at release. More than two before
version 1 means the model was not understood when the format was fixed.

---

<a id="r-15"></a>
### R-15 — The ANSI code grows into a framework
**Class:** LOW · **Probability:** low · **Impact:** low

**Mitigation and validation:** the line count and the presence of per-terminal
special cases, as stated in
[ADR-010](decisions/ADR-010-no-tui-framework.md). Past roughly 300 lines, that
record is wrong and should be revisited.

---

<a id="r-16"></a>
### R-16 — Odin changes break this project's own source
**Class:** LOW · **Probability:** medium · **Impact:** low

The tool is written in a language under active development.

**Mitigation:** the same pinning that
[ADR-009](decisions/ADR-009-toolchain-pinning.md) applies to the *target*
toolchain applies to the *build* toolchain. Continuous integration pins one Odin
version for building the tool itself.

**Validation:** a scheduled build against the current Odin release, separate
from the pinned build, so a break is visible early and does not block work.

---

<a id="r-17"></a>
### R-17 — The Odin runtime starts its own threads
**Class:** HIGH · **Status: CLOSED, 2026-08-05 — it does not**

A plain Odin program has **exactly one thread** under the debugger. The rule in
[ADR-012](decisions/ADR-012-single-threaded-target.md) can use a plain thread
count, with no refinement needed.

[ADR-012](decisions/ADR-012-single-threaded-target.md) ends a trace when a second
thread appears. That rule is correct only if a plain program has one thread.

**This is not known.** It is stated as unknown rather than assumed, because
assuming it is what produced the gap the review found.

**Mitigation:** the Phase 0 `thread-count` probe establishes the baseline before
any code depends on the rule. If the runtime does spawn threads, the rule
refines to "a thread that executes code in the student's source", which is
implementable but is a different rule and needs its own test.

**Validation:** the probe, and the `spawns-thread` fixture stopping at the right
step rather than at step 0.

---

<a id="r-18"></a>
### R-18 — No breakpoint-able free path
**Class:** MEDIUM · **Status: CLOSED, 2026-08-05 — the path exists**

`runtime::heap_free`, `runtime::mem_free`, `runtime::heap_allocator_proc`, and
libc `free` all resolve as symbols. **Phase 6a is possible**, so the cheap half
of closing [R-07](#r-07) is available.

The Odin allocator is selected through `context.allocator`, so there may be no
single symbol to break on for the free path.

**Consequence if it lands:** Phase 6a does not exist, and closing
[R-07](#r-07) requires the full allocation event stream, which costs more
debugger stops and therefore trades against [R-06](#r-06).

**Validation:** the Phase 0 `free-symbol` probe.

---

<a id="r-19"></a>
### R-19 — The debugger cannot be confined to the student's source
**Class:** HIGH · **Status: LANDED, 2026-08-05. Mitigation measured and adopted.**

**A plain `step` loop does not stay in the student's code.** Over 120 steps, 42
— **35%** — landed elsewhere: `heap_allocator.odin`, `internal.odin`,
`core_builtin.odin`, `error_checks.odin`, and twelve stops inside glibc's
`memset` assembly.

The review found this assumption with no probe and no fallback. The probe
confirms the assumption was **false**.

**Mitigation, measured:** check the stopped frame's source file; if it is not the
student's, `finish` out instead of stepping. The same program then produced 85
student steps with 4 escapes, at 1.31 ms per student step — **no slower per
student step than the naive loop**, because `finish` leaves a whole runtime call
in one operation.

This is no longer optional. It is
[SPEC-ADP-014](DEBUGGER-ADAPTER.md#spec-adp-014).

[REQ-FRAME-001](REQUIREMENTS.md#req-frame-001) requires steps only inside the
student's code. If stepping descends into the runtime and `core:`, the step
budget is spent inside `fmt.println` and the student's program never finishes.

Unlike the frame key, **this had no fallback specified**. It now has one: if the
debugger cannot be confined, the adapter steps by instruction and filters by
source line, which is slower and is bounded by
[R-06](#r-06) rather than by correctness.

**Validation:** the `only-student-code` probe, added by the review. Not run.

---

<a id="r-20"></a>
### R-07 — Allocation identity after a free
**Class:** HIGH · **Status: CLOSED by Phase 6a, 2026-08-05**

The adapter now breaks on the allocator's entry point and records what the
program handed back. A free event is **positive** evidence that a storage died —
the one kind [ADR-011](decisions/ADR-011-absence-is-not-evidence.md) says the
absence rule can never supply, because a budget can fake absence and cannot fake
a free.

`free-then-allocate` yields two identities. The version 1 test that asserted the
incorrect behaviour was replaced rather than deleted, and its successor asserts
the closed behaviour ([SPEC-TEST-021](TEST-STRATEGY.md#spec-test-021)).

**The symbol matters, and the obvious one is wrong.** `runtime::heap_free`
resolves and exposes a `ptr`, and that pointer is **eight bytes below** the
address the object lives at — it is the allocator's own base pointer. Matching it
never matches; "correcting" it by a guessed offset risks the opposite failure,
killing the identity of an object that is still alive.
`runtime::heap_allocator_proc` carries the student's pointer in `old_memory` when
`mode` is `Free`, and that address is exactly where the object lives.

**What is still true.** Without a free event the model must not invent a death,
so the absence rule and its guard remain. A toolchain whose allocator entry point
does not resolve keeps the version 1 behaviour rather than failing, and that case
still has a test.

---

### R-20 — Map entries are not readable through the type
**Class:** HIGH · **Status: LANDED 2026-08-05, DECIDED by [ADR-014](decisions/ADR-014-maps-are-counted-not-walked.md)**

```
map[string]int  →  struct map[string]int, fields ['data', 'len', 'allocator']
```

No key access, no value access. Odin packs the capacity into the low bits of the
data pointer and stores keys and values in parallel arrays. Reading an entry
means decoding that layout by hand, per Odin version, with no type-level help.

[MEMORY-MODEL.md](MEMORY-MODEL.md) §8 listed `map` alongside slice and string as
a composite the model recognises. Slice and string are `{data, len}` and were
trivial. **Map is not in the same class** and should never have been listed
beside them.

**Decided by [ADR-014](decisions/ADR-014-maps-are-counted-not-walked.md),
2026-08-05: counted, not walked.** A map is recorded with its type and its entry
count, and its entries are `unknown`.

Decoding the layout was rejected for version 1 because it produces **wrong
pairs** when it is wrong, and fails silently on a toolchain update: the layout
changes, the decoder still produces pairs, and nothing signals that they are
garbage. Dropping maps from the curriculum was rejected because it does not
apply — a student's own program may contain a map whatever the curriculum says,
so the tool needs this answer either way.

The risk is not closed, because the gap in the teaching is real. It is **decided**,
which is a different thing.

---

<a id="r-22"></a>
### R-22 — An explicitly uninitialised local cannot be told from an initialised one
**Class:** HIGH · **Status: ANSWERED — it cannot, by reading**

Odin's `= ---` leaves the storage untouched on purpose.

```odin
x: int = ---        // line 15, gdb reports x as declared here
y := 1              // line 16 - the FIRST step the line table has
```

**Measured 2026-08-05.** `x: int = ---` generates no code, so line 15 never
appears in the line table and is never a step. From the first step onward the
declaration line has passed, `yet_active` says the variable is live, and the tool
reads the storage — which holds `140729712422976`, whatever the previous call
left there.

DWARF describes where a variable lives and where it was declared. It does not
describe whether it has ever been assigned. There is nothing to read.

**This is the same shape as [R-21](#r-21)** and it is worth stating in the same
words: the tool is reporting the memory truthfully, and the memory is not yet
meaningful. The `not-yet-active` state
([SPEC-MEM-020](MEMORY-MODEL.md#spec-mem-020)) covers "the program has not
reached the declaration", which the tool CAN determine. It does not cover "the
declaration was reached and deliberately wrote nothing", which it cannot.

**What still works.** The case the state was built for — a local or an argument
read *before* its declaration line — is detected and produces `not-yet-active`.
That is the `prologue` fixture, and it passes. The gap is `= ---` alone, which a
student writes rarely and deliberately.

**What must not be claimed.** That the tool detects reading an uninitialised
variable. It does not. `uninitialised-local` is a fixture that records a limit,
like `dangling-pointer`, not one that asserts a safeguard.

**The path, if it is ever worth taking:** a `DW_AT_location` range that begins at
the first assignment would answer it, and Odin does not emit one. Otherwise it
needs the same machinery as Phase 6 — watching writes rather than reading state.

---

<a id="r-21"></a>
### R-21 — Use-after-free cannot be detected by reading
**Class:** HIGH · **Status: ANSWERED — it cannot**

```
morto := new(int); morto^ = 5
free(morto)
read through the pointer → 8313165202016105638, no exception
```

The region stays mapped. The tool sees a readable integer.

This changes what the project can claim. The `dangling-pointer` fixture was
specified to yield `unreadable`; for a freed-but-mapped pointer it will yield a
**plausible wrong value**, which is the failure the whole project exists to
avoid.

The `unreadable` path itself works — a genuinely unmapped address
(`0xdeadbeef`) raises a catchable `gdb.MemoryError` and the process survives.

**Consequence:** observing the allocator ([ROADMAP.md](ROADMAP.md) Phase 6) is
no longer only about identity. It is the **only** source of the fact "this
memory was freed". Its priority rises accordingly.

Until then, [SPEC-MEM-032](MEMORY-MODEL.md#spec-mem-032) states the limit, and
the documentation must not imply the tool finds use-after-free.

**Pointer expansion widened this, 2026-08-05.** Before Phase 2 the student met
R-21 only where their own code read a freed pointer. Now the tool follows
pointers, so any node still reachable through a stale pointer is *drawn*, with
whatever the freed region happens to hold. Tracing `linked-list-4` past its
`free` calls shows two nodes carrying `-8516251251570781361` where they held 4
and 3 a step earlier.

Nothing about this is a new defect — the values are what the memory says, and the
same limit produced them. What changed is how much of the picture it can reach.
That raises the priority of Phase 6 again rather than lowering it.

---

<a id="r-23"></a>
### R-23 — A nested struct's scalar fields were drawn as ONE shared storage
**Class:** BLOCKING for the picture's promise · **Status: FIXED 2026-08-06.**
**A second, smaller limit remains and is stated at the end.**

This is not a limit. **It is a wrong picture**, which is the one thing
[ADR-008](decisions/ADR-008-unknown-over-false.md) says must never ship.

The same struct, at the same values, rendered two ways:

```odin
Ponto :: struct { x: int, y: int }

p := Ponto{x = 3, y = 4}              // FLAT — correct
//   [2] struct main::Ponto
//       x = 3
//       y = 4

Casa :: struct { canto: Ponto, lado: int }
casa := Casa{canto = Ponto{x = 3, y = 4}, lado = 10}   // NESTED — wrong
//   [3] struct main::Ponto
//       x -> [4]
//       y -> [4]      <- the same identity as x
//   [4] int …
```

Two fields that are eight bytes apart are shown as **two names for one object**,
which is the exact vocabulary this tool uses for aliasing
([SPEC-TUI-002](TUI-SPEC.md#spec-tui-002)). A student reading that screen would
conclude that writing `casa.canto.x` changes `casa.canto.y`. It does not.

The value is elided as `…` on top of it, so the screen is both wrong and
uninformative.

**How it was found.** Writing a nested-struct exercise for the curriculum. The
reference solution failed its own assertions — `value_of("casa.canto.x")` could
not be read — and the render explained why. The exercise is withheld until this
is fixed; a course that teaches from this screen would teach the opposite of the
truth.

**The cause was not the suspected one.** Overlap-based storage grouping was
innocent. The adapter had already stopped expanding at a depth limit and marked
both fields **opaque**, carrying a `…` and no address. The model then built an
ENTITY for each opaque value — and every opaque value of one type has the same
key, because they all have address 0. Two fields collapsed into one identity
because neither had an identity to begin with.

**The fix.** An opaque value is not an object. It is a value the tool stopped
expanding, and it belongs in the slot as text, beside a scalar. Two lines in
`slot_from_value`, and the regression test is
`an_opaque_value_is_not_an_object`.

Nested fields now read:

```
  [3] struct main::Ponto
      x = …
      y = …
```

**What remains, and it is a limit rather than a lie:** the values are still
elided. A struct inside a struct is one level past the adapter's expansion
depth, so `value_of("casa.canto.x")` is `undetermined` — the tool says it did
not look, instead of claiming two fields are one object. Raising the depth is a
budget change ([ADR-006](decisions/ADR-006-budgets.md)) and its own piece of
work.

**`#soa` shares the same cause** and is presumably improved by the same fix; it
has not been re-probed.

<a id="r-24"></a>
### R-24 — A union has no rule, so it reads `unknown`
**Class:** MEDIUM · **Status: ANSWERED — it is honest, and it costs a chapter**

```odin
Value :: union { int, string }
v: Value = 42
//   v ? unknown (no rule for this shape)
```

The model has no rule for a tagged union, so it says so. That is the correct
behaviour under [ADR-008](decisions/ADR-008-unknown-over-false.md) — it does not
guess a variant — and it is why unions are not an exercise: a lesson whose whole
screen reads `unknown` teaches nothing about unions and everything about the
tool.

Unlike [R-20](#r-20), this one looks tractable: a union's tag and payload are
described in DWARF, so a rule could read the tag, choose the variant, and render
it. It is scoped work, not a wall.

**What must not be claimed:** that the tool covers Odin's type system. It covers
what it can read, and this is a named hole.

---

<a id="r-25"></a>
### R-25 — A pointer to a LOCAL drew that local's storage a second time
**Class:** BLOCKING for the picture's promise · **Status: FIXED 2026-08-06**

The sibling of [R-23](#r-23), and the opposite mistake. There, two objects were
drawn as one. Here, one object is drawn as two.

```odin
a := Ponto{x = 1, y = 2}
b := &a           // ONE Ponto exists. `b` is its address.
b.x = 9

//   a -> [2]
//   b -> [3]
//   [2] struct main::Ponto      [3] struct main::Ponto
//       x = 9                       x = 9
//       y = 2                       y = 2
```

Two entries, two identities, one storage. The values agree because the tool read
the same bytes twice, so the screen is self-consistent and still says something
false: that `a` and `b` are separate objects which happen to hold equal values.

A student reading it would conclude that assigning a struct and taking its
address produce the same picture. They produce opposite pictures, and telling
them apart is the whole subject of `06-aliasing`.

**Why no existing exercise caught it.** Every exercise that involves a pointer
points at a HEAP allocation (`new`), where the local IS the pointer and only one
entity is ever produced. A pointer to a local was never traced.

**The cause.** Identity is a function of address and epoch
([SPEC-MEM-002](MEMORY-MODEL.md#spec-mem-002)), and the two readings minted
different keys for it. An object reached as a frame variable was keyed on
`location` — where the name lives — while the same storage reached through a
pointer was keyed on its address. A view is identified by the buffer it points
at; an object is identified by where it IS, and now both spellings agree.

The adapter was correct throughout: it reported one object, at one address, and
the local's own value carried that same address.

**The fix.** Five lines in `entity_from_value`, and the regression test is
`one_storage_is_one_identity_however_it_was_reached`.

**What it unblocked.** `23-struct-copy` — "assigning a struct copies it" — ships
with this change, and its wrong answer is now rejected by `not_alias` with the
reason *two different objects*.

---

<a id="r-26"></a>
### R-26 — A fixed array of scalars is recorded as text, not as elements
**Class:** MEDIUM · **Status: OPEN, found 2026-08-06**

A slice records its elements as members named `[0]`, `[1]`, `[2]`. A fixed array
of scalars records `"text": "{2, 4, 6}"` and no members at all.

The picture reads the same to a person. It does not to an assertion: with
[SPEC-VAL-026](VALIDATION-SPEC.md#spec-val-026) an exercise can ask what
`marks[2]` is when `marks` is a slice, and cannot when it is a `[3]int`.

**Consequence.** Exercises about array contents have to be written against
slices. That is not a bad constraint — slices are the shape a student meets most
— but it is a constraint nobody chose, and an exercise author will hit it as a
silent `undetermined` rather than as a message.

**The fix is in the adapter**, which already emits elements for anything with a
`data` pointer and a length. A fixed array has neither; it has a static length in
its type, which is the very fact `03-fixed-arrays` teaches. Emitting members for
it would change the observation stream, so it changes the conformance goldens
and belongs in a change that regenerates them deliberately.

---

## 4. Risks deliberately not carried

| Not a risk here | Why |
|---|---|
| A hostile student program escaping a sandbox | There is no sandbox and none is claimed. [SAFETY.md](SAFETY.md) §1. |
| Data loss on the server | There is no server. [ADR-001](decisions/ADR-001-local-first-no-backend.md). |
| A student's code leaving the machine | Nothing leaves the machine, and a test runs the suite with networking disabled. [SPEC-SAFE-060](SAFETY.md#spec-safe-060). |
| The target program exhausting host memory | Stated non-goal. [SPEC-SAFE-051](SAFETY.md#spec-safe-051). The tool offers no protection the operating system does not already offer for a program the student ran themselves. |
| Debugger correctness | Out of scope. The probe suite tests our *use* of it. [TEST-STRATEGY.md](TEST-STRATEGY.md) §9. |
