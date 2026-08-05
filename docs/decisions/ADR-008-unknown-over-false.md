# ADR-008: Unknown is better than false — four value states, not a value and a blank

**Status:** accepted
**Date:** 2026-08-04

## Context
A reader of target memory has more outcomes than "got the value". A local
before its declaration holds stack garbage. A read through a dangling pointer
fails. A length of four billion makes the elements unknowable even though the
memory is readable.

A representation with one absent-value case forces all three into the same blank
space, and the student learns nothing from a blank.

## Options

**A. Value or nothing.** One optional field.
Cost: the three cases above are indistinguishable, on screen and in a test.

**B. Value or an error string.** One field plus free text.
Cost: the distinction exists but is not checkable. A renderer cannot decide
what to draw from prose, and a test cannot assert a state.

**C. Four explicit states.**
`valid`, `not-yet-active`, `unreadable`, `unknown`.
Cost: every consumer handles four cases.

## Decision
**C.** Defined in [MEMORY-MODEL.md](../MEMORY-MODEL.md) §4.

| State | Means | Typical cause |
|---|---|---|
| `valid` | The value was read and is trustworthy. | normal |
| `not-yet-active` | The variable exists in scope but has no assigned value yet. | the prologue, an undeclared local |
| `unreadable` | The read was attempted and failed. | a dangling or invalid pointer |
| `unknown` | The read succeeded, but the result cannot be interpreted truthfully. | a length that failed validation |

`unreadable` and `unknown` are deliberately separate. "I tried and could not" and
"I read it and it makes no sense" point the student at different bugs.

## Consequences

Easy:
- Every failure path has a state to produce, so
  [SPEC-SAFE-001](../SAFETY.md#spec-safe-001) — the tracer never dies on a read
  — has somewhere to land.
- A test asserts a state. [SPEC-TEST-061](../TEST-STRATEGY.md#spec-test-061)
  requires one golden screen showing all four, so a change that merges two of
  them fails.
- The validator gets its third verdict for free: a predicate over a
  non-`valid` value yields `undetermined`, never `fail`
  ([SPEC-VAL-001](../VALIDATION-SPEC.md#spec-val-001)).

Hard:
- Four cases in the renderer, the validator, and every consumer.
- Each state needs a distinct visual form that survives ASCII and monochrome
  mode.

## The rule this encodes
> Unknown is better than false.

It is [AGENT-GUIDE.md](../AGENT-GUIDE.md) Rule 4, and this record is the
structural reason it can be obeyed. A rule that says "never fabricate" is empty
unless the data model has a place to put the truth instead.

The tempting changes that violate it are listed in
[AGENT-GUIDE.md](../AGENT-GUIDE.md) §6. Two are worth repeating here because
both are *more informative* in the short term and wrong in the long term:
showing the last known value when a read fails, and reading `min(length, budget)`
elements from a corrupt length.

## Validation
Wrong if, in practice, `unknown` and `unreadable` are never both produced by
real student programs, which would mean one state is theoretical. Measure: the
distribution of states across the fixture corpus and across recorded student
runs, if any are ever collected locally by a consenting user.

Note that this measurement has no collection path, because nothing leaves the
machine ([SPEC-SAFE-060](../SAFETY.md#spec-safe-060)). In practice the fixture
corpus is the only evidence, and it is deliberately constructed to produce all
four states, so it cannot disprove the distinction. This validation is therefore
weak, and this record says so rather than pretending otherwise.
