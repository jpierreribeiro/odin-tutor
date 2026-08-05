# TRACEABILITY

Every requirement, the specification that realises it, the test that proves it,
and the phase that delivers it.

This table is the answer to two questions:

1. Is any requirement unspecified, or untested?
2. Is any test proving something no requirement asked for?

---

## 1. How to read the status column

| Status | Meaning |
|---|---|
| **planned** | Specified and assigned a test. Not built. This is the correct status for every row today. |
| **partly met** | The plan itself does not fully satisfy the requirement, and the gap is documented. |
| **at risk** | Delivery depends on an open unknown in [RISKS.md](RISKS.md). |

Most rows read **planned**. A row reads **met** only when its tests exist and
pass.

> **2026-08-05:** the Phase 1 skeleton exists and `./check.sh` is green, so a
> few rows have real tests behind them now. They are marked **met (unit)** —
> the test exists and passes, at the layer named. That is weaker than "met":
> an end-to-end test against a real target is still Phase 1's remaining work.

### The maintenance rule
This file is updated in the same change that adds a test or a requirement
([AGENT-GUIDE.md](AGENT-GUIDE.md) §3, gate G9). A requirement added without a
row here is a requirement nobody will test.

---

## 2. General (`REQ-GEN`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-GEN-001](REQUIREMENTS.md#req-gen-001) Local operation | [SPEC-SAFE-060](SAFETY.md#spec-safe-060) | full suite with networking disabled | 1 | planned |
| [REQ-GEN-002](REQUIREMENTS.md#req-gen-002) No hidden state | [SPEC-SAFE-043](SAFETY.md#spec-safe-043) | fresh `HOME`, named work directory | 1 | planned |
| [REQ-GEN-003](REQUIREMENTS.md#req-gen-003) External tools declared | [SPEC-ADP-004](DEBUGGER-ADAPTER.md#spec-adp-004), [SPEC-PLAT-030](PLATFORM-SUPPORT.md#spec-plat-030) | preflight unit tests; `odin` and `gdb` absent | 1 | planned |
| [REQ-GEN-004](REQUIREMENTS.md#req-gen-004) Deterministic trace | [SPEC-TRACE-060](TRACE-SPEC.md#spec-trace-060) | [SPEC-TEST-050](TEST-STRATEGY.md#spec-test-050) byte comparison, [SPEC-TEST-051](TEST-STRATEGY.md#spec-test-051) | 2 | planned |
| [REQ-GEN-005](REQUIREMENTS.md#req-gen-005) Source is never modified | [SPEC-SAFE-043](SAFETY.md#spec-safe-043) | file hashes equal before and after, including a failing run | 1 | planned |

---

## 3. Compile and execute (`REQ-EXEC`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-EXEC-001](REQUIREMENTS.md#req-exec-001) Debug build | [SPEC-ADP-002](DEBUGGER-ADAPTER.md#spec-adp-002), [SPEC-SAFE-041](SAFETY.md#spec-safe-041) | an exercise that tries to disable debug information is rejected | 1 | planned |
| [REQ-EXEC-002](REQUIREMENTS.md#req-exec-002) Compilation failure distinct | [SPEC-TRACE-050](TRACE-SPEC.md#spec-trace-050) | a fixture that does not compile | 1 | planned |
| [REQ-EXEC-003](REQUIREMENTS.md#req-exec-003) One execution per trace | [SPEC-PERF-001](PERFORMANCE.md#spec-perf-001) | process count during a full navigation session | 1 | planned |
| [REQ-EXEC-004](REQUIREMENTS.md#req-exec-004) Exit status preserved | [SPEC-OBS-032](OBSERVATION-SPEC.md#spec-obs-032) | `segfault`, `index-out-of-range` | 1 | planned |
| [REQ-EXEC-005](REQUIREMENTS.md#req-exec-005) Output captured separately | [SPEC-OBS-031](OBSERVATION-SPEC.md#spec-obs-031) | `prints-in-loop` | 1 | planned |
| [REQ-EXEC-006](REQUIREMENTS.md#req-exec-006) Cache keyed by source and toolchain | [SPEC-PLAT-030](PLATFORM-SUPPORT.md#spec-plat-030), [ADR-009](decisions/ADR-009-toolchain-pinning.md) | a compiler version change forces a rebuild | 1 | planned |
| [REQ-EXEC-007](REQUIREMENTS.md#req-exec-007) A second thread ends the trace | [ADR-012](decisions/ADR-012-single-threaded-target.md) | `spawns-thread` | 1 | planned, **at risk** — [R-17](RISKS.md#r-17) |

---

## 4. Trace (`REQ-TRACE`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-TRACE-001](REQUIREMENTS.md#req-trace-001) Navigation does not re-execute | [SPEC-PERF-001](PERFORMANCE.md#spec-perf-001) | no process is started during navigation | 2 | planned |
| [REQ-TRACE-002](REQUIREMENTS.md#req-trace-002) Backward navigation | [SPEC-TRACE-002](TRACE-SPEC.md#spec-trace-002) | `materialise_at_k32_equals_full_snapshots`, `keyframes_appear_at_the_interval` | 2 | **met (unit)** |
| [REQ-TRACE-003](REQUIREMENTS.md#req-trace-003) Random access | [SPEC-TRACE-001](TRACE-SPEC.md#spec-trace-001), [SPEC-PERF-022](PERFORMANCE.md#spec-perf-022) | jump latency on `long-trace` | 2, measured 4 | planned |
| [REQ-TRACE-004](REQUIREMENTS.md#req-trace-004) Versioned format | [SPEC-TRACE-070](TRACE-SPEC.md#spec-trace-070) … [SPEC-TRACE-072](TRACE-SPEC.md#spec-trace-072) | `an_unknown_trace_version_is_refused`, `an_unknown_schema_version_is_refused` | 2 | **met (unit)** |
| [REQ-TRACE-005](REQUIREMENTS.md#req-trace-005) Valid document under every condition | [SPEC-SAFE-031](SAFETY.md#spec-safe-031), [SPEC-SAFE-032](SAFETY.md#spec-safe-032) | every limit fixture; the document parses | 2 | planned |
| [REQ-TRACE-006](REQUIREMENTS.md#req-trace-006) No presentation data in the trace | [SPEC-TRACE-030](TRACE-SPEC.md#spec-trace-030) | a schema check rejects layout fields | 2 | planned |
| [REQ-TRACE-007](REQUIREMENTS.md#req-trace-007) Cumulative output position | [SPEC-OBS-031](OBSERVATION-SPEC.md#spec-obs-031) | `prints-in-loop` asserts the **full sequence** of lengths; `prints-utf8` asserts the unit | 2 | planned, see [R-10](RISKS.md#r-10) |

---

## 5. Memory (`REQ-MEM`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-MEM-001](REQUIREMENTS.md#req-mem-001) No raw address as identity | [SPEC-MEM-001](MEMORY-MODEL.md#spec-mem-001), [SPEC-MEM-002](MEMORY-MODEL.md#spec-mem-002) | `identity_is_never_an_address`, `the_render_contains_no_address`; schema bounds the id | 2 | **met (unit)** |
| [REQ-MEM-002](REQUIREMENTS.md#req-mem-002) Identity stable within a run | [SPEC-MEM-003](MEMORY-MODEL.md#spec-mem-003), [SPEC-MEM-044](MEMORY-MODEL.md#spec-mem-044) | `a_budget_never_changes_an_identity`, `a_complete_absence_does_advance_the_epoch`, `identity_survives_the_same_key` | 2 | **met (unit)** |
| [REQ-MEM-003](REQUIREMENTS.md#req-mem-003) Address reuse does not transfer identity | [SPEC-MEM-040](MEMORY-MODEL.md#spec-mem-040) … [SPEC-MEM-044](MEMORY-MODEL.md#spec-mem-044) | `free-then-allocate`, asserting the **incorrect** version 1 behaviour ([SPEC-TEST-021](TEST-STRATEGY.md#spec-test-021)) | 2, closed in 6 | **partly met** — [R-07](RISKS.md#r-07) |
| [REQ-MEM-004](REQUIREMENTS.md#req-mem-004) Null-data views are distinct | [SPEC-MEM-002](MEMORY-MODEL.md#spec-mem-002), [SPEC-MEM-006](MEMORY-MODEL.md#spec-mem-006) | `two_empty_views_are_distinct` | 2 | **met (unit)** |
| [REQ-MEM-005](REQUIREMENTS.md#req-mem-005) Shared storage represented | [SPEC-MEM-010](MEMORY-MODEL.md#spec-mem-010) … [SPEC-MEM-012](MEMORY-MODEL.md#spec-mem-012) | `a_sub_slice_shares_its_parents_storage_and_keeps_its_own_length`, `two_unrelated_buffers_do_not_share_storage` | 2 | **met (unit)** |
| [REQ-MEM-006](REQUIREMENTS.md#req-mem-006) Value equality is not identity | [SPEC-MEM-004](MEMORY-MODEL.md#spec-mem-004) | `equal_contents_are_not_one_object` | 2 | **met (unit)** |
| [REQ-MEM-007](REQUIREMENTS.md#req-mem-007) Four value states | [SPEC-MEM-020](MEMORY-MODEL.md#spec-mem-020) … [SPEC-MEM-022](MEMORY-MODEL.md#spec-mem-022), [ADR-008](decisions/ADR-008-unknown-over-false.md) | `the_four_states_survive_assembly`, `a_golden_shows_all_four_states_at_once`, `the_four_state_marks_are_all_different` | 2, rendered 4 | **met (unit)** |
| [REQ-MEM-008](REQUIREMENTS.md#req-mem-008) Not-yet-readable is not "no variables" | [SPEC-MEM-020](MEMORY-MODEL.md#spec-mem-020) | `an_empty_frame_does_not_claim_there_are_no_variables`; the adapter's `yet_active`, which turned a reported `n = 140737488342512` into `not created yet` | 3 | **met (unit)** |
| [REQ-MEM-009](REQUIREMENTS.md#req-mem-009) Composites shown by value | [SPEC-MEM-050](MEMORY-MODEL.md#spec-mem-050) … [SPEC-MEM-052](MEMORY-MODEL.md#spec-mem-052) | `string`, `slice-of-int`, `dynamic-array-append`, `struct-in-slice` | 2 | planned, **at risk** — [R-02](RISKS.md#r-02) |
| [REQ-MEM-010](REQUIREMENTS.md#req-mem-010) Unshaped pointers not followed | [SPEC-MEM-031](MEMORY-MODEL.md#spec-mem-031), [SPEC-SAFE-012](SAFETY.md#spec-safe-012) | `rawptr` asserts **zero reads** through the pointer | 2 | planned |
| [REQ-MEM-011](REQUIREMENTS.md#req-mem-011) Cycles terminate and are visible | [SPEC-MEM-030](MEMORY-MODEL.md#spec-mem-030), [SPEC-PERF-024](PERFORMANCE.md#spec-perf-024) | `cycle` | 2 | planned |

---

## 6. Frames (`REQ-FRAME`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-FRAME-001](REQUIREMENTS.md#req-frame-001) Only student code produces steps | [SPEC-OBS-020](OBSERVATION-SPEC.md#spec-obs-020) | a fixture calling into `core:` produces no step inside it | 3 | planned |
| [REQ-FRAME-002](REQUIREMENTS.md#req-frame-002) Frame identity is not stack position | [SPEC-MEM-060](MEMORY-MODEL.md#spec-mem-060) | `two-calls-one-line`, `deep-recursion` | 3 | planned, **at risk** — [R-04](RISKS.md#r-04) |
| [REQ-FRAME-003](REQUIREMENTS.md#req-frame-003) Return values attributed or withheld | [SPEC-MEM-061](MEMORY-MODEL.md#spec-mem-061) | the pair, built: `a_return_value_is_shown_only_for_its_own_invocation` and `a_matching_return_value_is_shown` | 3 | planned, **at risk** — [R-04](RISKS.md#r-04), [R-05](RISKS.md#r-05) |

---

## 7. Safety (`REQ-SAFE`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-SAFE-001](REQUIREMENTS.md#req-safe-001) Every read can fail safely | [SPEC-SAFE-001](SAFETY.md#spec-safe-001) | `dangling-pointer`, `segfault` | 2 | planned |
| [REQ-SAFE-002](REQUIREMENTS.md#req-safe-002) Length validated before use | [SPEC-SAFE-010](SAFETY.md#spec-safe-010), [SPEC-SAFE-011](SAFETY.md#spec-safe-011), [SPEC-MEM-013](MEMORY-MODEL.md#spec-mem-013) | `corrupt-length`, asserting **read sizes**, not the absence of a crash | 2 | planned |
| [REQ-SAFE-003](REQUIREMENTS.md#req-safe-003) Enumerated budgets | [SAFETY.md](SAFETY.md) §4, [SPEC-SAFE-020](SAFETY.md#spec-safe-020), [ADR-006](decisions/ADR-006-budgets.md) | `assembly_refuses_a_budget_disagreement` — and it fired on the first live run, catching a real mismatch | 2 | **met (unit)** |
| [REQ-SAFE-004](REQUIREMENTS.md#req-safe-004) A budget degrades, never corrupts | [SPEC-SAFE-030](SAFETY.md#spec-safe-030) … [SPEC-SAFE-032](SAFETY.md#spec-safe-032) | `many-objects`, `long-string`, `long-trace`, `infinite-loop`; every produced document parses | 2 | planned |
| [REQ-SAFE-005](REQUIREMENTS.md#req-safe-005) Truncation reaches the user | [SPEC-SAFE-030](SAFETY.md#spec-safe-030), [SPEC-TUI-030](TUI-SPEC.md#spec-tui-030) | `a_truncation_is_recorded_at_its_step`, `a_reached_budget_is_visible_on_screen` | 2, rendered 4 | **met (unit)** |
| [REQ-SAFE-006](REQUIREMENTS.md#req-safe-006) Survives target termination | [SPEC-OBS-032](OBSERVATION-SPEC.md#spec-obs-032), [SPEC-SAFE-050](SAFETY.md#spec-safe-050) | `segfault`, `infinite-loop` | 2 | planned |

---

## 8. Interface (`REQ-TUI`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-TUI-001](REQUIREMENTS.md#req-tui-001) Two regions | [SPEC-TUI-001](TUI-SPEC.md#spec-tui-001) … [SPEC-TUI-003](TUI-SPEC.md#spec-tui-003) | goldens | 4 | planned |
| [REQ-TUI-002](REQUIREMENTS.md#req-tui-002) References use stable labels | [SPEC-TUI-010](TUI-SPEC.md#spec-tui-010), [SPEC-TUI-020](TUI-SPEC.md#spec-tui-020), [ADR-007](decisions/ADR-007-labels-not-arrows.md) | `aliasing_shows_as_two_slots_with_one_label`, `shared_storage_is_marked_differently_from_aliasing` | 4 | **met (unit)** |
| [REQ-TUI-003](REQUIREMENTS.md#req-tui-003) Navigation commands | [SPEC-TUI-031](TUI-SPEC.md#spec-tui-031), [SPEC-TUI-032](TUI-SPEC.md#spec-tui-032) | input handling tests | 4 | planned |
| [REQ-TUI-004](REQUIREMENTS.md#req-tui-004) Non-interactive rendering | [SPEC-TUI-050](TUI-SPEC.md#spec-tui-050), [SPEC-TUI-051](TUI-SPEC.md#spec-tui-051) | every golden runs through `render` | 4 | planned |
| [REQ-TUI-005](REQUIREMENTS.md#req-tui-005) Degradation without colour or Unicode | [SPEC-TUI-040](TUI-SPEC.md#spec-tui-040) … [SPEC-TUI-044](TUI-SPEC.md#spec-tui-044) | the same fixture rendered three ways, compared for information content | 4 | planned |
| [REQ-TUI-006](REQUIREMENTS.md#req-tui-006) Resize | [SPEC-TUI-011](TUI-SPEC.md#spec-tui-011) | a narrow-terminal golden | 4 | planned |
| [REQ-TUI-007](REQUIREMENTS.md#req-tui-007) Terminal restored | [SPEC-TUI-061](TUI-SPEC.md#spec-tui-061) | forced exit, forced error, interrupt | 4 | planned |

---

## 9. Exercises (`REQ-EX`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-EX-001](REQUIREMENTS.md#req-ex-001) Declarative exercise | [SPEC-EX-001](EXERCISE-SPEC.md#spec-ex-001), [SPEC-EX-002](EXERCISE-SPEC.md#spec-ex-002), [SPEC-SAFE-041](SAFETY.md#spec-safe-041) | an exercise containing a script is rejected | 5 | planned |
| [REQ-EX-002](REQUIREMENTS.md#req-ex-002) Assertions evaluated against the trace | [SPEC-VAL-002](VALIDATION-SPEC.md#spec-val-002), [SPEC-VAL-010](VALIDATION-SPEC.md#spec-val-010) | a correct solution written differently from the reference passes | 5 | planned |
| [REQ-EX-003](REQUIREMENTS.md#req-ex-003) Three verdicts | [SPEC-VAL-001](VALIDATION-SPEC.md#spec-val-001), [SPEC-VAL-003](VALIDATION-SPEC.md#spec-val-003) | per predicate: `pass`, `fail`, `undetermined`, and behaviour on a truncated trace | 5 | planned |
| [REQ-EX-004](REQUIREMENTS.md#req-ex-004) Failure explains itself | [SPEC-VAL-040](VALIDATION-SPEC.md#spec-val-040) … [SPEC-VAL-042](VALIDATION-SPEC.md#spec-val-042) | a failing solution's message names the step and the expectation | 5 | planned |
| [REQ-EX-005](REQUIREMENTS.md#req-ex-005) Watch mode | — | a rapid edit sequence yields one verdict, for the last version | 5 | planned |

---

## 10. Platform (`REQ-PLAT`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-PLAT-001](REQUIREMENTS.md#req-plat-001) Declared support only | [SPEC-PLAT-001](PLATFORM-SUPPORT.md#spec-plat-001), [SPEC-PLAT-031](PLATFORM-SUPPORT.md#spec-plat-031) | the matrix has no row without a committed probe report | 0 | planned |
| [REQ-PLAT-002](REQUIREMENTS.md#req-plat-002) Toolchain checked, not assumed | [SPEC-PLAT-030](PLATFORM-SUPPORT.md#spec-plat-030), [ADR-009](decisions/ADR-009-toolchain-pinning.md) | preflight against a listed-broken version, and against an unlisted version | 0, enforced 1 | planned |

---

## 11. Performance (`REQ-PERF`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-PERF-001](REQUIREMENTS.md#req-perf-001) Navigation latency | [SPEC-PERF-010](PERFORMANCE.md#spec-perf-010), [SPEC-PERF-022](PERFORMANCE.md#spec-perf-022) | 99th-percentile jump latency on the largest fixture | 4 | planned |
| [REQ-PERF-002](REQUIREMENTS.md#req-perf-002) No super-linear assembly | [SPEC-PERF-020](PERFORMANCE.md#spec-perf-020), [SPEC-PERF-021](PERFORMANCE.md#spec-perf-021) | `assembly_cost_is_linear_in_steps` at 100, 400, 1600 — asserts structurally, so it cannot flake | 2 | **met (unit)** |

---

## 12. Errors (`REQ-ERR`)

| Requirement | Specification | Test | Phase | Status |
|---|---|---|---|---|
| [REQ-ERR-001](REQUIREMENTS.md#req-err-001) Three failure origins distinct | [TRACE-SPEC.md](TRACE-SPEC.md) §8 taxonomy | one fixture per origin: a compile error, a tool error, a target crash | 1 | planned |
| [REQ-ERR-002](REQUIREMENTS.md#req-err-002) Every error is named | [SPEC-TRACE-050](TRACE-SPEC.md#spec-trace-050) | `every_failure_explains_what_to_do`, `every_termination_has_a_sentence` — both enumerate the enum, so a new case with no message fails | 1 | **met (unit)** |

---

## 13. Tests that no requirement demands

A test in this list is either evidence for a decision, or a requirement that
should be written. Both are acceptable. An unexamined entry is not.

| Test | Why it exists | Disposition |
|---|---|---|
| `prints-utf8` unit consistency ([SPEC-TEST-030](TEST-STRATEGY.md#spec-test-030)) | A prior system lost whole traces to a character count guarding a byte limit | Serves [REQ-TRACE-005](REQUIREMENTS.md#req-trace-005). Kept as a named test because the general requirement would not have caught it. |
| `step-cost` probe | Measures the toolchain, not this project | Evidence for [ADR-009](decisions/ADR-009-toolchain-pinning.md) and R-06. Not a requirement, by [SPEC-TEST-042](TEST-STRATEGY.md#spec-test-042). |
| `no-debug-info` probe | Asserts a named error on a stripped executable | Serves [REQ-ERR-002](REQUIREMENTS.md#req-err-002) in the adapter's failure path. |
| Terminal restoration ([SPEC-TUI-061](TUI-SPEC.md#spec-tui-061)) | A tool that leaves a terminal unusable is remembered for that | **Closed.** [REQ-TUI-007](REQUIREMENTS.md#req-tui-007) was added after the review. |
| `thread-count`, `free-symbol` probes | Measure the toolchain and the runtime, not this project | Evidence for [R-17](RISKS.md#r-17) and [R-18](RISKS.md#r-18). Not requirements, by [SPEC-TEST-042](TEST-STRATEGY.md#spec-test-042). |
| `truncated-then-restored` | A budget must never change an identity | Serves [REQ-MEM-002](REQUIREMENTS.md#req-mem-002) through [SPEC-MEM-044](MEMORY-MODEL.md#spec-mem-044). |
| Materialisation equivalence at `K = 32` against `K = 1` | Proves the encoding, not a user-visible property | Serves [REQ-TRACE-002](REQUIREMENTS.md#req-trace-002) and [REQ-TRACE-003](REQUIREMENTS.md#req-trace-003). |
| The adapter's budget declaration check ([SPEC-SAFE-020](SAFETY.md#spec-safe-020)) | The core cannot verify a budget the adapter enforced | Serves [REQ-SAFE-003](REQUIREMENTS.md#req-safe-003). Its weakness is stated in [ADR-006](decisions/ADR-006-budgets.md). |

---

## 14. Requirements with no test

None. Every requirement above names at least one test.

This is a claim about **planning**, not about correctness. Every test in this
table is a description of a test that does not exist yet. The claim that matters
— "every requirement has a passing test" — cannot be made until Phase 5, and
[QUALITY-GATES.md](QUALITY-GATES.md) §4 forbids closing a phase before it holds
for that phase's scope.
