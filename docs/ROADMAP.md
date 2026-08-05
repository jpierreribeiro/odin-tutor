# ROADMAP

Phases, in order. Each phase is independently verifiable: it ends with a check
that a person other than its author can run, and whose result is not a matter of
opinion.

A phase is done when [QUALITY-GATES.md](QUALITY-GATES.md) §4 is satisfied for
it. Nothing here overrides that.

---

## 0. The shape of the plan

```
Phase 0  Validate the toolchain            ← no product code is written
Phase 1  Walking skeleton                  ← one scalar, end to end
Phase 2  The memory model                  ← the hard part
Phase 3  Frames and return values          ← the part most likely to fail
Phase 4  The interface
Phase 5  Exercises and the validator
────────────────────────────────────────── version 1
Phase 6  Allocator observation             ← closes a known incorrectness
Phase 7  Native adapter, other platforms   ← optional
```

### Why Phase 0 exists
Three BLOCKING unknowns ([RISKS.md](RISKS.md) §2) ask whether the debug
information supports the model **at all**. None can be closed by reasoning.
Writing the model first and discovering in Phase 2 that slices are opaque would
waste the model.

### Why Phase 3 is separate from Phase 2
Frame identity ([R-04](RISKS.md#r-04))
is the least validated part of the design and the one whose failure is
survivable. Separating it means a failure there does not stall the memory
picture, which is the product's core.

---

## Phase 0 — Validate the toolchain

> **A first pass ran on 2026-08-05** against Odin `dev-2026-08:9caff63` and gdb
> 15.1 on Ubuntu 24.04 x86-64. Report:
> [`fixtures/toolchain/2026-08-05-linux-x86_64.md`](../fixtures/toolchain/2026-08-05-linux-x86_64.md).
> R-01, R-02, R-03, R-04, R-05, R-17, R-18 closed. R-19 landed, with a measured
> mitigation now required as
> [SPEC-ADP-014](DEBUGGER-ADAPTER.md#spec-adp-014). R-06 measured at 1.31 ms per
> step. **Phase 1 is unblocked.**
>
> **Both remaining deliverables landed on 2026-08-05.** The 34 fixture programs
> of [TEST-STRATEGY.md](TEST-STRATEGY.md) §5 are in
> [`fixtures/programs/`](../fixtures/programs/), and the probe suite is at
> [`probes/`](../probes/): repeatable, exit-coded, and emitting its own report.
> A second combination has been claimed with it — Odin
> `dev-2026-07-nightly:819fdc7` with gdb 15.0.50 — so the mechanism is proven
> rather than assumed.
>
> Two findings from that work are recorded rather than fixed:
> [R-20](RISKS.md#r-20) still stands, and the `free-then-allocate` fixture
> needed a warm-up loop before it exercised the case it exists for. See
> [`fixtures/programs/README.md`](../fixtures/programs/README.md).

**Goal:** answer R-01, R-02, R-03 with evidence, and gather first numbers for
R-04, R-05, R-06.

**Inputs:** one pinned Odin version, one GDB version, Linux x86-64.

**Work:**
1. Write the fixture programs listed in
   [TEST-STRATEGY.md](TEST-STRATEGY.md) §5. These are Odin source files, not
   tool code.
2. Write the probe suite ([SPEC-TEST-041](TEST-STRATEGY.md#spec-test-041)) as a
   script. It may be written in any language; it is throwaway measurement, not
   product code.
3. Run every probe. Record the results.

**Outputs:**
- A committed probe report under `fixtures/toolchain/`.
- The first row of the compatibility table in
  [PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md) §5, or a documented statement that
  no combination passed.
- Real numbers replacing the estimates in [PERFORMANCE.md](PERFORMANCE.md) §2.

**Requirements addressed:** [REQ-PLAT-001](REQUIREMENTS.md#req-plat-001),
[REQ-PLAT-002](REQUIREMENTS.md#req-plat-002).

**Tests:** the probe suite is the test.

**Acceptance:**
1. `entry-symbol`, `line-table`, `struct-fields`, and `slice-fields` pass on at
   least one combination.
2. The `frame-key`, `finish-breakpoint`, `only-student-code`, and `thread-count`
   probes have a recorded result, whether pass or fail.
3. `step-cost` is recorded at three sizes.
4. `free-symbol` has a recorded result. It decides whether Phase 6a exists.
5. The report is committed.

**Dependencies:** none.

**Risks:** R-01, R-02, R-03 close here or the project stops.
R-04, R-05, R-06 get their first evidence.

### The decision this phase forces
If the four BLOCKING probes fail on every combination tried, **stop**. Do not
proceed to Phase 1 with a plan to work around it. Reopen
[ADR-004](decisions/ADR-004-in-debugger-extractor.md) and
[ADR-002](decisions/ADR-002-implementation-language.md), and consider Phase 7's
native adapter as the primary path rather than an optional one. That is a
different project with a different cost, and it deserves a decision rather than
a drift.

---

## Phase 1 — Walking skeleton

> **Built 2026-08-05.** The skeleton exists, compiles, and runs end to end on a
> real Odin program under gdb. `./check.sh` is green: `-vet -strict-style`
> clean, 36 tests across four packages, and both JSON schemas validating the
> real adapter output.
>
> What works: preflight, the observation format, the trace format with
> keyframes and deltas, identity with the epoch guard, overlap-based storage
> grouping, the four value states, the plain renderer, and the GDB extractor.
>
> What is not built: the interactive step player (Phase 4), the validator
> (Phase 5), the build cache, and the wiring that runs `odin build` and gdb
> from inside the tool. `assemble` and `render` are driven by hand today.
>
> Three defects the live run caught, each now a test:
> a variable before its declaration line reported stack garbage as a value;
> an argument at a procedure's signature line did the same, because the
> prologue had not run; and a sub-slice and its parent were given different
> storage identities, so the sharing mark was meaningless.

**Goal:** one integer variable, from source file to rendered screen, through
every component.

**Inputs:** Phase 0's answers.

**Work:**
1. CLI entry point, argument parsing.
2. Preflight: detect `odin` and `gdb`, check GDB has Python, compare versions
   against the table ([SPEC-PLAT-030](PLATFORM-SUPPORT.md#spec-plat-030)).
3. Build: compile the target with debug information, cached by source hash and
   toolchain version.
4. Launch the debugger and the extractor script; capture its output.
5. The extractor emits observation records for scalar locals only.
6. The core reads observation records and emits a trace with full snapshots
   (`K = 1`).
7. A plain renderer prints one step.
8. Thread detection and the `TARGET_BECAME_MULTITHREADED` terminal condition
   ([REQ-EXEC-007](REQUIREMENTS.md#req-exec-007)). It lands here, not later,
   because every phase after this one draws pictures that the rule protects.

**Outputs:** a running `trace` command and a `render` command
([SPEC-TUI-050](TUI-SPEC.md#spec-tui-050)); the first observation fixtures.

**Requirements addressed:** [REQ-GEN-001](REQUIREMENTS.md#req-gen-001),
[REQ-GEN-002](REQUIREMENTS.md#req-gen-002),
[REQ-EXEC-001](REQUIREMENTS.md#req-exec-001) …
[REQ-EXEC-005](REQUIREMENTS.md#req-exec-005),
[REQ-TRACE-002](REQUIREMENTS.md#req-trace-002),
[REQ-ERR-001](REQUIREMENTS.md#req-err-001),
[REQ-GEN-005](REQUIREMENTS.md#req-gen-005),
[REQ-EXEC-006](REQUIREMENTS.md#req-exec-006),
[REQ-EXEC-007](REQUIREMENTS.md#req-exec-007).

**Tests:** preflight unit tests including the "GDB without Python" case;
end-to-end on the `scalars` fixture; the `spawns-thread` fixture; the first
golden.

**Acceptance:**
1. `scalars` produces a trace whose step count matches the source lines
   executed.
2. Every preflight failure produces a named error, not a stack trace
   ([REQ-ERR-001](REQUIREMENTS.md#req-err-001)).
3. **The observation stream is recorded to a file and replayed to produce an
   identical trace with the debugger absent.** This is the phase's most
   important outcome: it makes every later phase testable in milliseconds.
4. No network access occurs. A test asserts this with networking disabled.
5. `spawns-thread` ends before the second thread runs, and the trace parses.
6. A full run leaves every student-authored file byte-identical.

**Dependencies:** Phase 0.

**Risks:** R-03 confirmed in the real preflight; R-08 confirmed or refuted by
the process launch.

---

## Phase 2 — The memory model

**Goal:** the picture. Identity, composites, pointers, and the states that say
"I do not know".

**Inputs:** observation fixtures from Phase 1.

**Work:**
1. Identity assignment: dense counters over a deterministic traversal
   ([SPEC-MEM-002](MEMORY-MODEL.md#spec-mem-002)).
2. Storage, object, and view separated
   ([MEMORY-MODEL.md](MEMORY-MODEL.md) §3).
3. Composite recognition: string, slice, dynamic array, fixed array, struct,
   map ([SPEC-MEM-050](MEMORY-MODEL.md#spec-mem-050)).
4. Pointer expansion with both budgets
   ([SPEC-PERF-021](PERFORMANCE.md#spec-perf-021)).
5. The four value states ([ADR-008](decisions/ADR-008-unknown-over-false.md)).
6. Epochs ([SPEC-MEM-040](MEMORY-MODEL.md#spec-mem-040)), with the evidence
   guard ([SPEC-MEM-044](MEMORY-MODEL.md#spec-mem-044),
   [ADR-011](decisions/ADR-011-absence-is-not-evidence.md)).
7. Keyframe and delta encoding, and materialisation
   ([ADR-005](decisions/ADR-005-trace-encoding.md)).
8. Read budgets in the adapter, and length validation before any read
   ([SPEC-SAFE-010](SAFETY.md#spec-safe-010)).

**Outputs:** the trace format at version 1; the invariant checks in
[MEMORY-MODEL.md](MEMORY-MODEL.md) §10 running over every test's trace.

**Requirements addressed:** [REQ-MEM-001](REQUIREMENTS.md#req-mem-001) …
[REQ-MEM-011](REQUIREMENTS.md#req-mem-011), except
[REQ-MEM-003](REQUIREMENTS.md#req-mem-003) (partly met) and
[REQ-MEM-008](REQUIREMENTS.md#req-mem-008) (Phase 3),
[REQ-SAFE-001](REQUIREMENTS.md#req-safe-001) …
[REQ-SAFE-006](REQUIREMENTS.md#req-safe-006),
[REQ-TRACE-001](REQUIREMENTS.md#req-trace-001),
[REQ-TRACE-003](REQUIREMENTS.md#req-trace-003) …
[REQ-TRACE-007](REQUIREMENTS.md#req-trace-007),
[REQ-PERF-002](REQUIREMENTS.md#req-perf-002).

**Tests:** every anti-lie fixture in
[SPEC-TEST-020](TEST-STRATEGY.md#spec-test-020) except the three frame ones;
determinism ([SPEC-TEST-050](TEST-STRATEGY.md#spec-test-050)); the
materialisation equivalence test at `K = 32` against `K = 1`; the growth-ratio
benchmark at 100, 400, and 1600 steps.

**Acceptance:**
1. `two-empty-slices` yields two identities. `sub-slice` yields two views, one
   storage, lengths 3 and 2, and a recorded sharing relation.
2. `cycle` terminates and shows the object's own identifier inside itself.
3. `corrupt-length` yields `unknown`, and no read exceeds the bound. Asserted by
   instrumenting the adapter's read sizes, not by absence of a crash.
4. `dangling-pointer` yields `unreadable` and the run completes.
5. Every fixture traced twice yields equal identities, with address
   randomisation left enabled.
6. The growth-ratio benchmark shows linear assembly cost.
7. `free-then-allocate` has a test asserting the **known-incorrect** version 1
   behaviour ([SPEC-TEST-021](TEST-STRATEGY.md#spec-test-021)).
8. `truncated-then-restored` keeps one identity across the truncated step. A
   budget never changes an identity.

**Dependencies:** Phase 1.

**Risks:** R-02 fully closes or lands. R-09 is prevented here or nowhere. R-07
is documented and tested as a gap.

---

## Phase 3 — Frames and return values

**Goal:** frame identity that survives recursion, and return values that are
never wrong.

**Inputs:** the frame-key evidence from Phase 0.

**Work:**
1. Frame records, call and return, depth.
2. The frame key: caller's program counter plus caller's stack pointer
   ([SPEC-MEM-060](MEMORY-MODEL.md#spec-mem-060)).
3. Return value capture and attribution.
4. The withholding rule ([SPEC-MEM-061](MEMORY-MODEL.md#spec-mem-061)).
5. The prologue state: a frame whose locals are not yet active
   ([SPEC-MEM-020](MEMORY-MODEL.md#spec-mem-020)).

**Outputs:** frame identity in the trace; the `fibonacci`,
`two-calls-one-line`, `prologue`, `deep-recursion`, and `uninitialised-local`
fixtures passing.

**Requirements addressed:** [REQ-FRAME-001](REQUIREMENTS.md#req-frame-001) …
[REQ-FRAME-003](REQUIREMENTS.md#req-frame-003).

**Tests:** the two-part `fibonacci` pair
([SPEC-TEST-022](TEST-STRATEGY.md#spec-test-022)) — one test forbidding a wrong
return value, one requiring a value in the simple case.

**Acceptance:**
1. `two-calls-one-line` yields two frame identities.
2. In `fibonacci`, **no shown return value contradicts its frame's argument.**
3. In `simple-call`, the return value **is** shown. Without this, acceptance 2
   passes by showing nothing.
4. `prologue` shows `not-yet-active`, and the renderer does not print "no
   variables".

**Dependencies:** Phase 2.

**Risks:** R-04 and R-05 close here, or
[REQ-FRAME-003](REQUIREMENTS.md#req-frame-003) is restated as a limit under
[SPEC-GATE-010](QUALITY-GATES.md#spec-gate-010).

### The rule for this phase
A partial success is acceptable and a false success is not. Shipping Phase 3
with return values withheld everywhere is a valid outcome. Shipping it with
return values that are usually right is not.

---

## Phase 4 — The interface

**Goal:** the step player a student uses.

**Inputs:** traces from Phase 3.

**Work:**
1. Terminal mode control, alternate screen, restoration on error and on signal.
2. The four-panel layout ([TUI-SPEC.md](TUI-SPEC.md) §2).
3. Navigation: forward, backward, jump, first, last.
4. Distinct marks for aliasing and for shared storage
   ([SPEC-TUI-020](TUI-SPEC.md#spec-tui-020)).
5. Visible forms for truncation, `unknown`, `unreadable`, and
   `not-yet-active`.
6. ASCII mode and monochrome mode.

**Outputs:** the interactive command; goldens for every value state.

**Requirements addressed:** [REQ-TUI-001](REQUIREMENTS.md#req-tui-001) …
[REQ-TUI-006](REQUIREMENTS.md#req-tui-006),
[REQ-PERF-001](REQUIREMENTS.md#req-perf-001).

**Tests:** goldens through `render`; input handling and terminal restoration
tested separately ([SPEC-TEST-060](TEST-STRATEGY.md#spec-test-060)); the
navigation latency measurement.

**Acceptance:**
1. Navigation to any step completes under 16 ms at the 99th percentile on the
   largest fixture ([SPEC-PERF-010](PERFORMANCE.md#spec-perf-010)).
2. One golden shows all four value states on one screen
   ([SPEC-TEST-061](TEST-STRATEGY.md#spec-test-061)).
3. Removing colour and Unicode loses no information. Asserted by comparing the
   information content of the three renderings, not their appearance.
4. The terminal is restored after a forced error and after an interrupt.
5. No step in the interface re-runs the program or the compiler.

**Dependencies:** Phase 3. Phase 4 may start against Phase 2 traces, with the
frame panel incomplete.

**Risks:** R-11.

---

## Phase 5 — Exercises and the validator

**Goal:** the tool becomes a course rather than a viewer.

**Inputs:** a trace, and the exercise format.

**Work:**
1. Exercise loading, and the guarantee that an exercise is data
   ([SPEC-EX-001](EXERCISE-SPEC.md#spec-ex-001)).
2. The predicate set ([VALIDATION-SPEC.md](VALIDATION-SPEC.md) §4).
3. Three verdicts, with `undetermined` never counted as a pass
   ([SPEC-VAL-001](VALIDATION-SPEC.md#spec-val-001)).
4. Watch mode: re-run on file change.
5. The first exercises, in order of the concepts in
   [EXERCISE-SPEC.md](EXERCISE-SPEC.md).

**Outputs:** the exercise runner; a starting curriculum.

**Requirements addressed:** [REQ-EX-001](REQUIREMENTS.md#req-ex-001) …
[REQ-EX-004](REQUIREMENTS.md#req-ex-004),
[REQ-ERR-002](REQUIREMENTS.md#req-err-002).

**Tests:** per predicate, one test each for `pass`, `fail`, and `undetermined`,
plus one for behaviour under a truncated trace
([QUALITY-GATES.md](QUALITY-GATES.md) §3).

**Acceptance:**
1. Every reference solution passes every assertion of its exercise.
2. **Every exercise rejects at least one plausible wrong solution**
   ([SPEC-EX-052](EXERCISE-SPEC.md#spec-ex-052)). The worked example is the
   sub-slice exercise whose wrong solution produces the right printed output.
3. A truncated trace produces `undetermined`, never `fail`.
4. No reference solution reaches any budget
   ([SPEC-EX-051](EXERCISE-SPEC.md#spec-ex-051)).

**Dependencies:** Phase 2 for the trace; Phase 4 for the student's loop, though
the validator can be tested through the plain renderer alone.

**Risks:** R-12.

---

## Version 1

Version 1 is Phases 0 through 5 on Linux x86-64, with:

- one row in the compatibility table, backed by a committed probe report;
- every gate in [QUALITY-GATES.md](QUALITY-GATES.md) §2 marked for Release;
- [REQ-MEM-003](REQUIREMENTS.md#req-mem-003) documented as **partly met**, with
  its test asserting the current behaviour;
- [SPEC-SAFE-051](SAFETY.md#spec-safe-051) documented as a non-goal.

Two known gaps ship. Both are written down, both have tests, and neither is a
fabricated picture.

---

## Phase 6 — Allocator observation

**Goal:** close [R-07](RISKS.md#r-07),
the one known incorrectness in version 1.

It splits in two, and the cheap half may be enough.

### Phase 6a — Free events only
Break on the free path alone. A free event is positive evidence that a storage
died, which is exactly what [ADR-011](decisions/ADR-011-absence-is-not-evidence.md)
says the model lacks. Frees are far rarer than allocations in a teaching
program, so the cost in debugger stops is a fraction of 6b.

Phase 6a exists only if the Phase 0 `free-symbol` probe found a breakpoint-able
entry. If it did not, this phase is skipped and 6b is the only path.

### Phase 6b — Full allocation events

**Work:** break on the Odin runtime's allocation and free entry points, record
an allocation event stream in the observation format, and drive the epoch from
it ([SPEC-MEM-043](MEMORY-MODEL.md#spec-mem-043)).

**Acceptance:** `free-then-allocate` yields two identities, and its Phase 2 test
— which asserts the incorrect behaviour — is replaced, not deleted quietly.
[REQ-MEM-003](REQUIREMENTS.md#req-mem-003) becomes fully met in
[TRACEABILITY.md](TRACEABILITY.md).

**Why it is not in version 1:** the Odin allocator is chosen through
`context.allocator`, so there is no single fixed symbol to break on; it
multiplies debugger stops, which costs time against R-06; and it needs its own
validation on every toolchain version.

**Dependencies:** Phase 2, and a Phase 0-style probe for the allocator symbols.

---

## Phase 7 — Native adapter and other platforms

Optional. The project does not depend on any of it.

| Item | What it is | Why it is deferred |
|---|---|---|
| macOS | An LLDB adapter, plus the rights the operating system requires for debugging | A second adapter, a second probe run, and a second architecture (R-13) |
| A native Odin adapter | `ptrace` plus a DWARF reader, removing GDB | Large, Linux-only, and it removes an external tool rather than adding a capability |
| Windows | A different debug format and a different debug API | WSL2 is the version 1 answer ([SPEC-PLAT-020](PLATFORM-SUPPORT.md#spec-plat-020)) |

### The gate every item here shares
A new adapter must derive the **same trace** from its records as the reference
adapter, for every fixture. Any difference is explained in that adapter's
document ([SPEC-ADP-020](DEBUGGER-ADAPTER.md#spec-adp-020)).

That gate is why the adapter boundary and the two document formats exist
([ADR-003](decisions/ADR-003-two-document-formats.md)). If it cannot be met,
the boundary was drawn in the wrong place, and that is worth knowing.

---

## What is deliberately not on this roadmap

| Item | Why |
|---|---|
| A web interface | [ADR-001](decisions/ADR-001-local-first-no-backend.md). A future one would consume the trace, not change the architecture. |
| Sharing a trace with a teacher | Needs a transport, which needs a decision about what leaves the machine. Not decided, so not planned. |
| A second target language | The memory model is specific to a manual-memory language with Odin's composites. |
| A sandbox | [SAFETY.md](SAFETY.md) §1. |
| Multi-threaded programs | Frame identity, stepping, and the picture all assume one thread. Adding threads is not an increment; it is a new model. |
