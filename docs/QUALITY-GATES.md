# QUALITY-GATES

When work is complete. "It compiles" is not on this page.

---

## 1. The gate list

| # | Gate |
|---|---|
| G1 | A requirement exists and is referenced by identifier. |
| G2 | A specification exists for the behaviour. |
| G3 | A design decision is recorded when the choice was not forced. |
| G4 | The implementation exists. |
| G5 | Unit tests exist and pass. |
| G6 | A fixture test exists, driven by a recorded observation stream. |
| G7 | An integration test exists, using the real toolchain. |
| G8 | A regression test exists for every bug this work fixed. |
| G9 | Documentation is updated, including [TRACEABILITY.md](TRACEABILITY.md). |
| G10 | Trace compatibility is stated: unchanged, or a version increase with a migration note. |
| G11 | No known false visualisation is introduced. The anti-lie suite passes. |
| G12 | Determinism holds: the fixture traces equal across two runs. |
| G13 | Performance budgets hold, with a recorded measurement. |
| G14 | The compatibility matrix is updated, with probe evidence. |

---

## 2. Which gates are mandatory, by milestone

| Gate | Prototype | MVP | Release |
|---|---|---|---|
| G1 requirement | — | ✔ | ✔ |
| G2 specification | — | ✔ | ✔ |
| G3 ADR | ✔ *(if architectural)* | ✔ | ✔ |
| G4 implementation | ✔ | ✔ | ✔ |
| G5 unit tests | — | ✔ | ✔ |
| G6 fixture tests | — | ✔ | ✔ |
| G7 integration tests | — | ✔ | ✔ |
| G8 regression tests | ✔ | ✔ | ✔ |
| G9 documentation | — | ✔ | ✔ |
| G10 trace compatibility | — | ✔ | ✔ |
| G11 anti-lie suite | ✔ | ✔ | ✔ |
| G12 determinism | — | ✔ | ✔ |
| G13 performance | — | — | ✔ |
| G14 compatibility matrix | — | — | ✔ |

<a id="spec-gate-001"></a>
<a id="spec-gate-000"></a>
### SPEC-GATE-000 — A phase may require a gate before its milestone does
The matrix is a floor, not a ceiling. A [ROADMAP.md](ROADMAP.md) phase may make a
gate mandatory earlier than the milestone column shows, and its acceptance
criteria win.

The live case: Phase 2 requires the growth-ratio benchmark (G13) although G13 is
marked Release-only. The defect it guards against is invisible on a small input
and expensive to remove later.

<a id="spec-gate-001"></a>
### SPEC-GATE-001 — Two gates are mandatory even for a prototype
**G8** and **G11**. A prototype may lack documentation, tests for new features,
and performance evidence. It may not reintroduce a known lie, and it may not fix
a bug without leaving a test behind.

*Rationale:* a prototype becomes the product. Everything else on this list can
be added later. Those two cannot, because by then nobody remembers which
picture was wrong.

---

## 3. Gates by change type

### A new debugger adapter
| Gate | Requirement |
|---|---|
| G2 | The adapter is documented in [DEBUGGER-ADAPTER.md](DEBUGGER-ADAPTER.md). |
| G6 | It produces observation fixtures for the full fixture-program set. |
| G7 | The core derives the **same trace** from its records as from the reference adapter, for every fixture. Any difference is explained in the adapter's document. |
| G11 | The anti-lie suite passes on its fixtures. |
| G14 | The matrix gains a row, with probe evidence. |

[SPEC-ADP-020](DEBUGGER-ADAPTER.md#spec-adp-020).

### A new trace format version
| Gate | Requirement |
|---|---|
| G3 | An ADR states why the change could not be additive. |
| G10 | The version increases by one, and a migration note exists. |
| G6 | A fixture exists at the new version. Fixtures at old versions are kept. |
| G9 | [TRACE-SPEC.md](TRACE-SPEC.md) is updated, including §10. |

[SPEC-TRACE-072](TRACE-SPEC.md#spec-trace-072).

### A new exercise
| Gate | Requirement |
|---|---|
| G4 | `start.odin`, `solution.odin`, `exercise.json`, `README.md`. |
| G5 | The reference solution passes every assertion. |
| G11 | **At least one plausible wrong solution is rejected.** [SPEC-EX-052](EXERCISE-SPEC.md#spec-ex-052). |
| G13 | The reference solution reaches no budget. [SPEC-EX-051](EXERCISE-SPEC.md#spec-ex-051). |

### A new assertion predicate
| Gate | Requirement |
|---|---|
| G2 | [VALIDATION-SPEC.md](VALIDATION-SPEC.md) §4 gains an entry. |
| G5 | Tests cover `pass`, `fail`, and `undetermined` for it. |
| G5 | Its behaviour under a truncated trace is tested. |

*Rationale:* the third row is where a predicate silently turns a missing fact
into a failure and blames the student.

### A change to a budget default
| Gate | Requirement |
|---|---|
| G3 | An ADR, or an amendment to [ADR-006](decisions/ADR-006-budgets.md). |
| G13 | A recorded measurement in the change. [SPEC-PERF-032](PERFORMANCE.md#spec-perf-032). |

---

## 4. Definition of done, per phase

A [ROADMAP.md](ROADMAP.md) phase is done when:

1. every acceptance criterion in the phase is met;
2. every gate mandatory for the milestone is satisfied;
3. the phase's risks in [RISKS.md](RISKS.md) are closed or restated with new
   evidence;
4. [TRACEABILITY.md](TRACEABILITY.md) has no requirement in the phase's scope
   without a test.

<a id="spec-gate-010"></a>
### SPEC-GATE-010 — A phase does not close with an unexplained gap
A requirement that the phase could not meet is restated as a known limit, with a
test that asserts the current behaviour
([SPEC-TEST-021](TEST-STRATEGY.md#spec-test-021)) and a risk entry.

---

## 5. What "complete" never means

| Not sufficient | Why |
|---|---|
| "It compiles." | Says nothing about the picture. |
| "It runs on my machine." | The matrix decides support, not one machine. |
| "The tests pass." | Which tests? G11 is separate for a reason. |
| "The output looks right." | The output is text. The picture is the product. |
| "It matches the old behaviour." | The old behaviour includes the known lies. |
