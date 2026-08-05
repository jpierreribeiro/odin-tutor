# TEST-STRATEGY

How correctness is established, and where the boundary between test kinds lies.

---

## 1. The failure this strategy targets

The dangerous defect in this project does not crash and does not throw. It draws
a believable picture that is wrong. Ordinary testing does not find it, because
ordinary testing asserts that the program produced *something*.

Every layer below exists to make one specific class of wrong picture detectable.

### The rule
> **Every bug becomes a regression test, and a bug that produced a plausible
> wrong picture becomes a test that asserts the picture, not the absence of an
> error.**

---

## 2. Test kinds and where each runs

> **As of 2026-08-05** the unit, model-fixture, and golden layers exist and run:
> 36 tests across `src/obs`, `src/model`, `src/render`, and `src/preflight`,
> in under 60 ms, with no debugger and no compiler for the target. Run them with
> `./check.sh`.

| Kind | Runs in | Needs `odin`? | Needs `gdb`? | Speed |
|---|---|---|---|---|
| Unit | `odin test` | no | no | ms |
| Model fixture | `odin test` | no | no | ms |
| Golden render | `odin test` | no | no | ms |
| Validator | `odin test` | no | no | ms |
| Adapter contract | script | yes | yes | s |
| End-to-end | script | yes | yes | s |
| Probe / compatibility | script | yes | yes | s |
| Performance | script | no (fixtures) | no | s |

<a id="spec-test-001"></a>
### SPEC-TEST-001 — The boundary
A test that can run without a debugger **must** run without a debugger. The
observation fixture makes that possible for the whole model, the whole renderer,
and the whole validator.

*Rationale:* those are the layers where the dangerous defects live. Tying their
tests to a debugger would make them slow, environment-dependent, and therefore
run rarely.

---

## 3. The fixture pyramid

```
        end-to-end          few, slow, need the full toolchain
     ┌──────────────┐
     │ adapter      │       one per adapter, proves it satisfies SPEC-OBS
     ├──────────────┤
     │ observation  │  ◄──  the pivot: recorded streams
     │ fixtures     │
     ├──────────────┤
     │ model        │       many, fast, no external tool
     │ golden       │
     │ validator    │
     └──────────────┘
```

<a id="spec-test-010"></a>
### SPEC-TEST-010 — Observation fixtures are the pivot
A recorded observation stream plus its expected trace is the primary test input.
See [OBSERVATION-SPEC.md](OBSERVATION-SPEC.md) §8.

<a id="spec-test-011"></a>
### SPEC-TEST-011 — Fixtures are generated, never hand-written
[SPEC-OBS-040](OBSERVATION-SPEC.md#spec-obs-040). A hand-written fixture can
encode a shape the adapter never produces, and then the test proves nothing.

<a id="spec-test-012"></a>
### SPEC-TEST-012 — Regenerating a fixture requires reviewing the diff
Regeneration is a command. Accepting the result is a review step. A regenerated
fixture whose diff is not understood is a silently changed contract.

---

## 4. Anti-lie tests

The tests that exist only to catch a plausible wrong picture. These are the most
important tests in the repository.

<a id="spec-test-020"></a>
### SPEC-TEST-020 — Every known false-visualisation bug has a named test
| Fixture | The lie it prevents | Asserts |
|---|---|---|
| `two-empty-slices` | two empty slices become one object | two identities; the interface shows two entries |
| `sub-slice` | a sub-slice is drawn with the parent's length | two view identities, one storage, lengths 3 and 2, sharing recorded |
| `two-equal-lists` | equal contents become one object | two identities |
| `prologue` | "no variables" at a call step | `variable_state == not_yet_active`, and the render does not say "no variables" |
| `uninitialised-local` | stack garbage shown as a value | state is `not-yet-active` at the declaring line, `valid` after |
| `fibonacci` | a return value attributed to the wrong invocation | **no shown return value contradicts its frame's argument** |
| `two-calls-one-line` | one frame identity for two invocations | two frame identities |
| `cycle` | infinite expansion, or a hidden cycle | terminates; a field refers to its own object identity |
| `invalid-pointer` | a fabricated object behind an unmapped address | `unreadable`, and the tool completes. **Measured:** `0xdeadbeef` raises a catchable `gdb.MemoryError`. |
| `dangling-pointer` | claiming the tool detects use after free | **the value is shown as an ordinary value.** A freed region stays mapped and reads as plausible garbage. The test asserts that the tool does **not** claim `unreadable` here, and the documentation does not promise use-after-free detection. [R-21](RISKS.md#r-21) |
| `corrupt-length` | thirty plausible elements from a corrupt length | `unknown` for the value; no read exceeds the bound |
| `rawptr` | an invented target for an unshaped pointer | pointer value recorded; zero reads through it |
| `free-then-allocate` | a new object inherits a freed object's identity | **known partly-failing; see below** |
| `truncated-then-restored` | a display budget changes an identity | the identity is equal before and after the truncated step ([SPEC-MEM-044](MEMORY-MODEL.md#spec-mem-044)) |
| `spawns-thread` | memory written by another thread is drawn as if a shown line produced it | the trace ends before the second thread runs, and carries `TARGET_BECAME_MULTITHREADED` |

<a id="spec-test-021"></a>
### SPEC-TEST-021 — A test may assert a known limit
`free-then-allocate` asserts the version 1 behaviour, which is *incorrect* by
[REQ-MEM-003](REQUIREMENTS.md#req-mem-003). The test documents the gap and fails
loudly if the behaviour changes without the requirement being met.

*Rationale:* a known gap with a test is engineering. A known gap without one is
a rumour.

<a id="spec-test-022"></a>
### SPEC-TEST-022 — The `fibonacci` assertion is stated as a property
The test does not assert a list of expected return values. It asserts:

> for every step that shows a return value, that value equals the correct result
> for that frame's argument.

A trace that shows **no** return values passes this. That is intended: withholding
is allowed, lying is not. A separate test asserts that the simple non-recursive
case *does* show its value, so that withholding everything cannot pass both.

*Rationale:* this pair is the exact shape a prior system got wrong. Its
"return never lies" check became vacuously true once the code stopped emitting
the values it inspected, and nothing noticed. Two tests are needed: one that
forbids the lie, one that requires the value where it is knowable.

<a id="spec-test-023"></a>
### SPEC-TEST-023 — Every schema invariant is checked mechanically
[MEMORY-MODEL.md](MEMORY-MODEL.md) §10 lists them. They run over every trace
produced by every test, not only over dedicated fixtures.

---

## 5. Fixture programs

The minimum set. Each is a small Odin program under `fixtures/programs/`.

**Values and structure**
`scalars`, `string`, `fixed-array`, `nested-struct`, `struct-in-slice`

**Slices**
`slice-of-int`, `two-empty-slices`, `sub-slice`, `dynamic-array-append`,
`two-equal-lists`

**Pointers and graphs**
`pointer-to-struct`, `linked-list-4`, `cycle`, `rawptr`, `invalid-pointer`,
`dangling-pointer`, `free-then-allocate`, `truncated-then-restored`

**Frames**
`simple-call`, `two-calls-one-line`, `fibonacci`, `deep-recursion`,
`prologue`, `uninitialised-local`

**Failure and limits**
`segfault`, `index-out-of-range`, `infinite-loop`, `corrupt-length`,
`many-objects`, `long-string`, `long-trace`, `spawns-thread`

**Output**
`prints-in-loop`, `prints-utf8`

<a id="spec-test-030"></a>
### SPEC-TEST-030 — `prints-utf8` is not optional
A fixture whose output contains multi-byte characters exists specifically to
catch a unit mismatch between a character count and a byte limit
([SPEC-SAFE-031](SAFETY.md#spec-safe-031)).

---

## 6. Probe suite

The probe suite answers "does this toolchain work?", separately from "is this
code correct?".

<a id="spec-test-040"></a>
### SPEC-TEST-040 — The probe suite gates the compatibility matrix
A row is added to [PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md) §5 only when the
probe suite passes and its report is committed.

<a id="spec-test-041"></a>
### SPEC-TEST-041 — Probes
| Probe | Asserts | Class if it fails |
|---|---|---|
| `entry-symbol` | The debugger resolves the student's entry procedure | BLOCKING |
| `line-table` | Stepping visits the expected source lines in order | BLOCKING |
| `struct-fields` | Field names and values are readable | BLOCKING |
| `slice-fields` | A slice's data pointer and length are readable | BLOCKING |
| `only-student-code` | Stepping stays inside the student's source and does not descend into the runtime or `core:` | HIGH |
| `frame-key` | The caller's program counter and stack pointer are readable at depth ≥ 2, and are stable within one invocation | HIGH |
| `finish-breakpoint` | A return value is observable and attributable | HIGH |
| `thread-count` | A plain single-threaded Odin program has exactly one thread under the debugger | HIGH |
| `thread-event` | A short-lived thread is caught by the creation **event**, not by a per-stop count | HIGH |
| `map-entries` | Map keys and values are reachable at all | HIGH |
| `free-symbol` | The default allocator's free path has a breakpoint-able entry | MEDIUM |
| `no-debug-info` | A stripped executable yields `DEBUG_INFO_MISSING`, not a crash | MEDIUM |
| `step-cost` | Wall time per step, on three sizes | MEDIUM |

<a id="spec-test-042"></a>
### SPEC-TEST-042 — A probe failure is a supported-platform failure, not a bug
A probe that fails on a new toolchain version means that version is not
supported. It does not mean the tool is broken. The matrix records it.

---

## 7. Determinism tests

<a id="spec-test-050"></a>
### SPEC-TEST-050 — Same input, same trace
Every fixture is traced **twice**. The traces are compared **byte for byte**
after removing the fields in
[SPEC-TRACE-060](TRACE-SPEC.md#spec-trace-060), not only by identity.

These fixtures are traced **ten** times instead of twice, because a
non-deterministic traversal order would hide in them:

`linked-list-4`, `cycle`, `many-objects`, `two-equal-lists`, `sub-slice`,
`free-then-allocate`

[REQ-GEN-004](REQUIREMENTS.md#req-gen-004).

*Why byte comparison and not identity comparison:* comparing identities would
pass a run-to-run difference in a value, a length, or an output position. A byte
comparison costs nothing extra and catches all three.

*Rationale:* this is the cheapest possible check that no address leaked into an
identity.

<a id="spec-test-051"></a>
### SPEC-TEST-051 — Address randomisation is left enabled
The tests do not disable address-space randomisation. Disabling it would hide
exactly the defect SPEC-TEST-050 exists to find.

---

## 8. Golden tests

<a id="spec-test-060"></a>
### SPEC-TEST-060 — Golden output is the plain renderer, not the interactive screen
Goldens are produced by `render` ([SPEC-TUI-050](TUI-SPEC.md#spec-tui-050)).
The interactive interface is tested for input handling and terminal restoration,
not for pixel content.

<a id="spec-test-061"></a>
### SPEC-TEST-061 — A golden covers every value state
At least one golden shows `valid`, `not-yet-active`, `unreadable`, and `unknown`
in one screen, so that a change that merges two of them fails a test.

---

## 9. What is not tested, and why

| Not tested | Reason |
|---|---|
| The debugger's own correctness | Out of scope. The probe suite tests our *use* of it. |
| The Odin compiler | Same. |
| Terminal emulator behaviour | Golden tests read text. Emulator differences are handled by the ASCII and monochrome modes. |
| Performance of the debugger | Bounded, not optimised ([PERFORMANCE.md](PERFORMANCE.md) §6). |
| Curriculum quality | Pedagogy is reviewed by a human, not asserted by a test. Each exercise's *assertions* are tested ([SPEC-EX-052](EXERCISE-SPEC.md#spec-ex-052)). |
