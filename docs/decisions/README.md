# Decision log

Every architectural decision, why it was forced, and what would prove it wrong.

A record here is not a preference. It exists because a choice was made that
another competent engineer could reasonably have made differently, and the next
person needs the reasoning rather than the result.

---

## Index

| ID | Decision | Status | Forced by | Reversible? |
|---|---|---|---|---|
| [ADR-001](ADR-001-local-first-no-backend.md) | Local-first. No backend, no server, no network. | accepted | The stated scope of the project | Yes, but a future remote mode is a new architecture, not a flag |
| [ADR-002](ADR-002-implementation-language.md) | Odin for everything the project controls; an external debugger for what it does not | accepted | The absence of an Odin-native DWARF and `ptrace` stack | Partly — [ADR-004](ADR-004-in-debugger-extractor.md) and Phase 7 both bear on it |
| [ADR-003](ADR-003-two-document-formats.md) | Observation records from the adapter; a trace from the core | accepted | Keeping identity, sharing, and delta logic out of the adapter | Expensive — two schemas are already versioned |
| [ADR-004](ADR-004-in-debugger-extractor.md) | A script inside GDB, not GDB/MI over a pipe | accepted | [REQ-SAFE-002](../REQUIREMENTS.md#req-safe-002): a length must be validated *before* it sizes a read | Yes, at a documented cost in safety |
| [ADR-005](ADR-005-trace-encoding.md) | Keyframe plus delta, `K = 32` | accepted | Random access and backward navigation are primary operations | `K` is configuration; the shape is a format version |
| [ADR-006](ADR-006-budgets.md) | Read budgets at the read; every budget degrades into the trace | accepted | An unbounded read on corrupt input; two measured failures in a prior system | No — it is the safety model |
| [ADR-007](ADR-007-labels-not-arrows.md) | Labels and identifiers, not drawn arrows | accepted | A terminal is a character grid | Yes for a future graphical consumer, which reads the trace |
| [ADR-008](ADR-008-unknown-over-false.md) | Four value states: `valid`, `not-yet-active`, `unreadable`, `unknown` | accepted | "Unknown is better than false" needs somewhere to put the truth | No — it is the project's premise |
| [ADR-009](ADR-009-toolchain-pinning.md) | The toolchain is a versioned dependency with an evidence-backed compatibility table | accepted | The correctness of the picture depends on what the compiler emits | No — removing it removes the ability to detect a regression |
| [ADR-010](ADR-010-no-tui-framework.md) | Direct ANSI output, no terminal framework | accepted | No mature Odin terminal library; [ADR-007](ADR-007-labels-not-arrows.md) removed the hard part | Yes, cheaply |
| [ADR-011](ADR-011-absence-is-not-evidence.md) | The epoch advances on absence only when the observation was complete | accepted | A display budget could change the identity of a living object | No — it is [ADR-008](ADR-008-unknown-over-false.md) applied to identity |
| [ADR-012](ADR-012-single-threaded-target.md) | A second thread ends the trace with a terminal condition | accepted | With two threads, memory changes with no line responsible | Yes, but tracing threads needs a different model, not a flag |
| [ADR-013](ADR-013-odin-conventions.md) | Odin conventions: errors last, arena per trace, `tutor_*` package names, no `using`/`any` | accepted | Otherwise every contributor decides these again, differently | Cheaply, but a mixed codebase is the cost |

[ADR-000](ADR-000-template.md) is the template. It is not a decision.

ADR-011 and ADR-012 were written **after** the consistency review, to close the
two defects it found. Their presence is the review doing its job.

---

## The two records that constrain everything else

**[ADR-001](ADR-001-local-first-no-backend.md)** removes a whole class of
concern — transport, authentication, sandboxing, data residency — and rules out
a whole class of solution. Anything that reaches for a server contradicts it.

**[ADR-008](ADR-008-unknown-over-false.md)** is the reason this project has
different tests, a different validator, and a different failure behaviour from a
tool that merely visualises. Every "we could show something plausible here"
decision is already made, and it is made against.

---

## What is decided and what is not

### Decided
The thirteen records above.

### Deliberately open
| Question | Why it stays open | Decided when |
|---|---|---|
| Whether a native Odin adapter replaces GDB | It depends on numbers Phase 0 does not produce, and on a cost that only matters after version 1 works | After version 1, if at all. [ROADMAP.md](../ROADMAP.md) Phase 7 |
| Whether the epoch rule is enough without observing the allocator | The gap is known and bounded ([R-07](../RISKS.md#r-07)), and [ADR-011](ADR-011-absence-is-not-evidence.md) narrowed what the rule claims | Phase 6a if the free path is breakpoint-able, otherwise 6b |
| Whether `K = 32` is the right keyframe interval | It is a measured number and there is no measurement yet | Phase 0 gives bytes per step; Phase 4 gives jump latency |
| macOS adapter shape | A second debugger's capabilities are unknown to this project | Its own phase, its own ADR |
| Whether a trace can ever be shared with another person | It needs a transport, and a transport contradicts [ADR-001](ADR-001-local-first-no-backend.md) | Not planned. Reopening it means a new record, not an exception |

An open question is not an oversight. Each one above is open because deciding it
today would mean deciding it without evidence, and a decision without evidence
is the thing this directory exists to prevent.

---

## Writing a new record

Copy [ADR-000](ADR-000-template.md). Number it next. Add a row to the index
above.

The **Validation** section is not optional:

> A decision with no way to be proven wrong is a preference, not a decision.

Superseding a record does not delete it. Set its status to `superseded by
ADR-nnn` and leave the reasoning in place. The reasoning is the reason the
directory exists; the conclusion is the smaller half.
