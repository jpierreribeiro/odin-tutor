# REVIEW

A consistency review of this specification set, performed before the planning
phase closed.

This is not a summary. It is the list of places where the documents disagree
with each other, where a requirement has no home, and where the project cannot
honestly claim to be right yet.

**Reviewed:** 22 documents, 10 decision records, a template, and a decision
log index, at the close of planning.
**Nothing is implemented.** Every finding below is about the documents.

---

## 1. Contradictions

### C-1 — Determinism is stated at two different strengths
[REQ-GEN-004](REQUIREMENTS.md#req-gen-004) requires **ten** traces of one
fixture to be **byte-identical** after the non-deterministic fields are removed.
[SPEC-TEST-050](TEST-STRATEGY.md#spec-test-050) requires **two** traces and
compares **identities only**.

The specification is weaker than the requirement in two independent ways. A
run-to-run difference in a value, a length, or an output position would satisfy
the specification and violate the requirement.

**RESOLVED.** The specification was raised, not the requirement lowered.
[SPEC-TEST-050](TEST-STRATEGY.md#spec-test-050) now compares **byte for byte**.
Repetition was reconciled in the other direction: every fixture twice, and six
named identity-dense fixtures ten times, because repetition cost is linear in
trace time and two runs already vary the address layout. The reason is written
into [REQ-GEN-004](REQUIREMENTS.md#req-gen-004) rather than left in this file.

### C-2 — The epoch rule can change the identity of a living object
[REQ-MEM-002](REQUIREMENTS.md#req-mem-002): "While an object exists, its logical
identity SHALL NOT change between steps."
[SPEC-MEM-041](MEMORY-MODEL.md#spec-mem-041) rule 2 increases the epoch when
"the address was absent from the reachable set for at least one step and then
reappeared". The epoch is part of the key, and
[SPEC-MEM-003](MEMORY-MODEL.md#spec-mem-003) only holds identity stable "while
the key holds".

An object can leave the reachable set and still exist. Two ways, both realistic:

1. The only pointer to it sits in a frame or a field that the
   `objects_per_step` budget truncated. A **budget** would then change an
   **identity**.
2. During a list splice, the only live reference is briefly in a register the
   adapter does not read.

The picture would report a death and a birth where a mutation occurred — the
exact inverse of the failure that
[R-07](RISKS.md#r-07) documents.

**RESOLVED** by [ADR-011](decisions/ADR-011-absence-is-not-evidence.md).

Rule 2 now fires only when **no step in which the address was absent carries a
truncation record**. An incomplete observation is not evidence.

Deleting rule 2 outright was considered and rejected: it would make
`free(node); node = new(Node)` — the ordinary manual-memory teaching sequence —
always show a mutation instead of a death and a birth. That trades a rare wrong
picture for a common one.

The guard widens [R-07](RISKS.md#r-07) slightly, and that is recorded there.
The register-temporary case (2 above) survives, and is narrower than this review
first stated: DWARF describes register-resident *variables*, and the build
disables optimisation, so the gap is limited to unnamed temporaries.
[SPEC-MEM-044](MEMORY-MODEL.md#spec-mem-044) states the invariant and names the
test.

### C-3 — Performance evidence is required before its gate is mandatory
[QUALITY-GATES.md](QUALITY-GATES.md) §2 marks G13 (performance, with a recorded
measurement) as mandatory only at Release. [ROADMAP.md](ROADMAP.md) Phase 2
acceptance criterion 6 requires the growth-ratio benchmark to pass, and Phase 2
is MVP-level work.

**RESOLVED.** [SPEC-GATE-000](QUALITY-GATES.md#spec-gate-000) now states that
the matrix is a floor and a phase's acceptance criteria win. The live case is
named there.

### C-4 — Two mechanical inconsistencies, already corrected
Recorded so the corrections are visible rather than silent.

| Was | Now |
|---|---|
| `ARCHITECTURE.md` §3.4 titled "The four buckets" over a five-row table | "The dependency buckets" |
| `ROADMAP.md` Phase 2 claimed `REQ-MEM-001 … REQ-MEM-011` while `TRACEABILITY.md` assigns `REQ-MEM-008` to Phase 3 | Phase 2 now excepts `REQ-MEM-008` |

---

## 2. Missing requirements

Behaviour that is specified, planned, or tested, with no requirement behind it.

**All five are now closed.** The table records what was added.

| Gap | Where it appeared with no requirement | Added |
|---|---|---|
| The terminal is restored on exit, on error, and on a signal | [SPEC-TUI-061](TUI-SPEC.md#spec-tui-061) | [REQ-TUI-007](REQUIREMENTS.md#req-tui-007) |
| The build is cached by source hash **and toolchain version** | [ROADMAP.md](ROADMAP.md) Phase 1; [AGENT-GUIDE.md](AGENT-GUIDE.md) §6 warns against caching across a toolchain change | [REQ-EXEC-006](REQUIREMENTS.md#req-exec-006) |
| Watch mode re-runs on a file change | [ROADMAP.md](ROADMAP.md) Phase 5 | [REQ-EX-005](REQUIREMENTS.md#req-ex-005) |
| The tool never modifies the student's source | Nowhere. It is assumed throughout. | [REQ-GEN-005](REQUIREMENTS.md#req-gen-005) |
| The tool operates on a single-threaded target, and says so when it cannot | [ROADMAP.md](ROADMAP.md) excludes threads from scope; nothing detects a second thread | [REQ-EXEC-007](REQUIREMENTS.md#req-exec-007), via [ADR-012](decisions/ADR-012-single-threaded-target.md) |

The last row was the serious one: the only identified case where the
specification set would have let the tool draw a believable wrong picture **by
design** rather than by defect. The tool now stops when a second thread appears,
produces a valid partial trace, and names the terminal condition. It does not
continue behind a disclaimer.

---

## 3. Unresolved architectural decisions

Listed in [decisions/README.md](decisions/README.md) §"Deliberately open", and
repeated here with the cost of leaving each open.

| Open question | Cost of leaving it open |
|---|---|
| Whether a native Odin adapter replaces GDB | None before version 1. It is the fallback if [R-01](RISKS.md#r-01) lands, and it is a much larger project. |
| Whether the epoch rule suffices without observing the allocator | A known incorrectness ships. Bounded and tested. |
| Whether `K = 32` is right | None. It is configuration. |
| The macOS adapter's shape | None before version 1. |
| Whether a trace can ever be shared | None. Reopening it contradicts [ADR-001](decisions/ADR-001-local-first-no-backend.md). |

Two more are open and are **not** in that list, because they were found by this
review:

| Open question | Why it matters |
|---|---|
| The guard for [C-2](#1-contradictions) | Without it, a budget can change an identity. |
| Whether a threaded target is refused or traced | See §2, last row. |

---

## 4. Unsupported assumptions

Statements the documents rely on that have no evidence behind them.

| Assumption | Where | Status |
|---|---|---|
| A step is about 4 KB, so 2500 steps is about 10 MB | [TRACE-SPEC.md](TRACE-SPEC.md) §2 encoding table | **Invented.** The table's whole first row is an estimate. Phase 0 measures it. The *conclusion* (keyframe plus delta) does not rest on it — [ADR-005](decisions/ADR-005-trace-encoding.md) decides on random access and corruption containment, not size. |
| Applying 31 deltas fits in 16 ms | [SPEC-PERF-010](PERFORMANCE.md#spec-perf-010) | Unmeasured. Depends on the step size above. |
| Compilation takes 1–3 s for a single file | [PERFORMANCE.md](PERFORMANCE.md) §2 | Unmeasured. |
| The debugger can be made to stop only inside the student's source | [SPEC-OBS-020](OBSERVATION-SPEC.md#spec-obs-020), [REQ-FRAME-001](REQUIREMENTS.md#req-frame-001) | Plausible from experience with the same technique elsewhere. Not probed. A probe was added by this review; it has not run. |
| `odin` produces one executable from one file, with a predictable name | Assumed by the build step | Trivially checkable, never stated. |
| `os2.process_start` can drive a child with pipes | [ADR-002](decisions/ADR-002-implementation-language.md) | The API exists and carries the fields. Its stability is [R-08](RISKS.md#r-08). |
| A student can install GDB with Python | [R-03](RISKS.md#r-03) | Distribution-dependent. Not surveyed. |
| Sixteen colours are enough | [ADR-010](decisions/ADR-010-no-tui-framework.md) | Follows from "colour is decoration". Consistent, not evidenced. |

The most important row is the fourth. Everything about "only the student's code
produces steps" rests on a technique that has not been probed on this toolchain,
and unlike the frame key it has **no fallback specified**. If the debugger
cannot be confined to the student's source, the step count explodes into runtime
internals and the wall budget is spent there.

**Action taken:** an `only-student-code` probe was added to
[SPEC-TEST-041](TEST-STRATEGY.md#spec-test-041), classified HIGH. Adding a probe
fills a gap; it does not change a contract, so it was applied rather than
raised. The assumption itself stays unsupported until Phase 0 runs it.

---

## 5. Requirements without tests

**None.** Every requirement in [TRACEABILITY.md](TRACEABILITY.md) names at least
one test.

That claim is worth exactly what it says and no more: every requirement has a
*described* test. None of those tests exists. The claim that matters — every
requirement has a **passing** test — cannot be made before Phase 5, and
[QUALITY-GATES.md](QUALITY-GATES.md) §4 forbids closing a phase before it holds
within that phase's scope.

Three requirements have a test that is knowingly weaker than the requirement:

| Requirement | Why the test is weaker |
|---|---|
| [REQ-MEM-003](REQUIREMENTS.md#req-mem-003) | The test asserts the **incorrect** version 1 behaviour. [SPEC-TEST-021](TEST-STRATEGY.md#spec-test-021). |
| [REQ-SAFE-003](REQUIREMENTS.md#req-safe-003) | The core cannot verify a budget the adapter enforced. It compares a **declaration**. An adapter that lies is undetectable. [ADR-006](decisions/ADR-006-budgets.md). |
| [REQ-GEN-004](REQUIREMENTS.md#req-gen-004) | See [C-1](#1-contradictions). |

---

## 6. Tests without requirements

Enumerated in [TRACEABILITY.md](TRACEABILITY.md) §13. One is a genuine gap
(terminal restoration, §2 above). The rest are evidence for decisions or
narrower cases of a broader requirement, and each is dispositioned there.

One class deserves naming: the **probe suite** proves things about the
*toolchain*, not about this project. By
[SPEC-TEST-042](TEST-STRATEGY.md#spec-test-042) a probe failure is an
unsupported platform, not a defect. Probes therefore correctly have no
requirement behind them, and the compatibility table is their output.

---

## 7. Platform risks

| Risk | Class | Note |
|---|---|---|
| Odin's DWARF quality on the pinned toolchain | BLOCKING | [R-01](RISKS.md#r-01). The evidence is genuinely mixed and is recorded as mixed. |
| GDB without Python | BLOCKING | [R-03](RISKS.md#r-03). The fallback is a documented reduction in safety, not an equivalent. |
| macOS: a second adapter, plus debugging rights | MEDIUM | [R-13](RISKS.md#r-13). Not version 1. |
| Apple silicon and any non-x86-64 architecture | MEDIUM | The frame key reads a stack pointer and a program counter whose meaning during a call is calling-convention dependent. [SPEC-PLAT-040](PLATFORM-SUPPORT.md#spec-plat-040) requires re-probing per architecture. |
| Windows | — | Not a risk, because it is not claimed. WSL2 is the answer. [SPEC-PLAT-020](PLATFORM-SUPPORT.md#spec-plat-020). |

The compatibility table is **empty**. Until Phase 0 runs, the honest statement is
that this project supports no platform. The table is deliberately left with no
rows rather than filled with plausible ones.

---

## 8. Security risks

The tool provides **no security boundary and claims none**
([SAFETY.md](SAFETY.md) §1). Within that, four things remain:

| Risk | Handling | Residual |
|---|---|---|
| A downloaded exercise scripts the debugger through an initialisation file in the working directory | The debugger is invoked with the flag that ignores it. [SPEC-SAFE-040](SAFETY.md#spec-safe-040) | Low. This is the one place the local model still needs care. |
| An exercise changes the build or runs a script | An exercise is data. [SPEC-EX-001](EXERCISE-SPEC.md#spec-ex-001), [SPEC-SAFE-041](SAFETY.md#spec-safe-041) | Low, and mechanically checkable. |
| A student's program exhausts host memory | **Not bounded.** [SPEC-SAFE-051](SAFETY.md#spec-safe-051) | Accepted and stated. The tool offers no protection the operating system does not already offer for a program the student ran themselves. |
| An adapter under-enforces a read budget | Only its declaration is compared. [ADR-006](decisions/ADR-006-budgets.md) | **Real.** It is the accepted price of enforcing budgets at the read, and it is the weakest link in the safety model. |

The last row is the honest security finding of this review: the safety model's
central rule — every read is bounded — is enforced in the component the core
cannot audit.

---

## 9. Performance risks

| Risk | Note |
|---|---|
| Cost per step is unknown | [R-06](RISKS.md#r-06). Every wall-time number in [PERFORMANCE.md](PERFORMANCE.md) is an expectation. Phase 0 replaces them. |
| Trace assembly becoming quadratic | [R-09](RISKS.md#r-09). **This has happened before**, with numbers: 2.0 s at 533 steps, 46.7 s at 2500. Its consequence was not slowness — it made the step limit unreachable, so long traces died by timeout inside the measuring code. Prevented by [SPEC-PERF-020](PERFORMANCE.md#spec-perf-020) and a growth-ratio benchmark, or by nothing. |
| Pointer expansion cost being steps × expansions | [SPEC-PERF-021](PERFORMANCE.md#spec-perf-021). Also measured before: 20 nodes 1.7 s, 40 nodes 3.4 s, 80 nodes 12 s, 150 a timeout — with a per-step bound already in place. Both bounds exist for this reason. |
| The 16 ms navigation budget | Unvalidated, and it depends on a step size that is currently an estimate. |

---

## 10. Where correctness cannot honestly be claimed

The list a reader should hold onto.

1. ~~**Frame identity under recursion.**~~ **Proven on 2026-08-05.** 25 of 25
   invocations of `fib(6)` attributed correctly, zero wrong values, and the two
   calls on one source line produced two distinct return addresses. The floor
   ([SPEC-MEM-061](MEMORY-MODEL.md#spec-mem-061)) stands, but it is now a floor
   under a working mechanism rather than under a hope.

2. ~~**Return values.**~~ **Proven, with one caveat carried into the
   implementation:** a `FinishBreakpoint` on a recursive procedure that also
   carries an ordinary breakpoint must return `False` from `stop()`, or the
   deeper call interleaves and no value is seen.

3. **Allocation identity.** [SPEC-MEM-042](MEMORY-MODEL.md#spec-mem-042) is a
   **known incorrectness that ships in version 1**. In one specific case a new
   object inherits a freed object's identity. It does not fabricate a value and
   does not expose an address, and it has a test that asserts the wrong
   behaviour so that a change is loud.

4. **Identity stability across a truncation.** Resolved in the specification by
   [ADR-011](decisions/ADR-011-absence-is-not-evidence.md), with one residual
   named there. The invariant is stated and has a test. Neither has run.

5. ~~**Reading composite types.**~~ **Proven.** Struct fields, slice
   `{data, len}`, elements, and strings all read. A sub-slice's data pointer sat
   8 bytes past its parent's, so shared storage is detectable from the
   observation alone.

6. **Confining the debugger to the student's code.** **The assumption was
   false.** 35% of stops landed in the runtime or in glibc assembly. A
   mitigation was measured and is now required
   ([SPEC-ADP-014](DEBUGGER-ADAPTER.md#spec-adp-014)). This is the one place
   where the review found an assumption and the probe refuted it.

7. **Some numbers.** Cost per step (1.31 ms) and compile time (0.98 s) are
   measured. Navigation latency, startup, trace size, and memory are **not**.
   Those four still read like commitments and are not.

9. **Maps.** [R-20](RISKS.md#r-20). The type gives no entry access, and the
   decision about what to do has not been made. Until it is, a map shows its
   count and marks its entries `unknown`.

10. **Use after free.** [R-21](RISKS.md#r-21). Not detectable by reading, at
    all. The documentation must not imply otherwise, and Phase 6 is the only
    path.

8. **Threaded programs.** Out of scope, and the tool now stops rather than
   guessing. Whether the detection baseline holds is [R-17](RISKS.md#r-17), and
   it is unknown.

### Findings from the second probe pass, 2026-08-05

The first pass tested the specification's assumptions about the debugger. The
second tested its assumptions about **Odin**, and found three that were wrong.

| Assumption | Reality |
|---|---|
| `core:os/os2` provides process control | **The package does not exist.** It was absorbed into `core:os`. The capability is real and measured; the name in the plan had already expired. |
| A `dangling-pointer` fixture yields `unreadable` | **It yields a plausible integer.** A freed region stays mapped. The tool cannot detect use-after-free by reading. [R-21](RISKS.md#r-21) |
| A second thread is caught by watching the thread list | **A per-stop count never fires.** The thread lived and died between two stops. Only `gdb.events.new_thread` catches it. |
| `map` is a composite like slice and string | **It is not.** The type exposes `['data', 'len', 'allocator']` and no entry access. [R-20](RISKS.md#r-20) |

The third one is the most instructive. A count at each step is the obvious
implementation of [ADR-012](decisions/ADR-012-single-threaded-target.md), it
reads as correct, and it would have shipped a safeguard that never fires — worse
than none, because its presence implies protection.

### What changed after this review
Two contract defects were closed by decision (C-1, C-2), one gate tension was
closed by clarification (C-3), and all five missing requirements were written.
That work opened three new unknowns — R-17, R-18, R-19 — because each decision
now depends on a fact about the toolchain that nobody has measured.

**That is the expected shape.** Resolving a specification defect does not
produce certainty; it converts a hidden assumption into a named probe.

### The honest summary
Everything above the adapter boundary — the model, the identity rules, the
trace format, the renderer, the validator — can be **specified and tested
without a debugger**, and this review found two contract defects in it (C-1,
C-2), both now closed by decision.

Everything below that boundary rested on assumptions about the Odin toolchain
and GDB. **On 2026-08-05 those assumptions were tested rather than reasoned
about.** Six held, two were wrong in detail (DWARF 4 not 3; `main::main` not
`main.main`), and one was wrong outright: stepping is *not* confined to the
student's source, and a mitigation was needed.

That is what Phase 0 is for, and it is why it writes no product code. The
project now supports one combination it can prove, and
[ADR-009](decisions/ADR-009-toolchain-pinning.md) is the reason that is stated
as one row rather than as a general claim.

---

## What this review did not do

It did not review pedagogy, the curriculum, or whether the exercises teach.
[TEST-STRATEGY.md](TEST-STRATEGY.md) §9 places that with a human reviewer, and
this review is not one.
