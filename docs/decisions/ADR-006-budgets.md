# ADR-006: Budgets are enforced at the read, and degrade into the trace

**Status:** accepted
**Date:** 2026-08-04

## Context
The target program is untrusted input to the tracer
([SAFETY.md](../SAFETY.md) §1). Without bounds, a student's bug becomes the
tool's crash: a corrupt length drives an unbounded read, a linked structure
makes pointer expansion quadratic, a loop never ends.

Bounds are not optional. Where they are checked, and what happens when they are
reached, are the decisions.

## Options

### Where a budget is checked

**A. In the core, after the adapter delivers the data.**
Uniform, testable without a debugger, and one place to change.

**B. At the read, inside the adapter.**
Duplicated in every adapter, and not testable without a debugger.

### What happens when a budget is reached

**C. Fail the run.** Simple, and honest in the sense that nothing is hidden.

**D. Truncate silently.** Produces a picture that looks complete and is not.

**E. Truncate and record the truncation in the trace, at the step.**

## Decision
**B for any budget that bounds a read. A for the rest. E always.**

The split is not a preference. A budget on a read cannot be enforced after the
read: by the time the core sees a value derived from a length of four billion,
the read already happened. [SPEC-SAFE-010](../SAFETY.md#spec-safe-010). The
table in [SAFETY.md](../SAFETY.md) §3 assigns each budget to a side and states
why.

**D is rejected** as the project's central failure mode: a believable picture
that is wrong.

**C is rejected** because a bounded trace is worth more than no trace. A student
whose linked list exceeded the expansion budget still gets the step player, the
frames, and the values — with the structure marked as not expanded. Failing the
run would take all of it away to punish one limit.

## Consequences

Easy:
- A read is bounded where it happens, so no unbounded read exists anywhere.
- Every limit is visible to the student
  ([REQ-SAFE-005](../REQUIREMENTS.md#req-safe-005)), so a missing element is
  never mistaken for an absent element.

Hard:
- The core cannot verify a budget the adapter enforced. It only compares the
  adapter's declaration with its own configuration
  ([SPEC-SAFE-020](../SAFETY.md#spec-safe-020)). An adapter that lies about what
  it enforced is not detectable. This is accepted, and it is the price of B.
- Every new adapter re-implements the read budgets, correctly.

## The two failures this record exists to prevent

Both are measured facts from a prior system, not hypotheticals.

1. **A budget in the wrong unit.** A character count guarding a byte limit. Any
   text outside ASCII pushed the document past the limit, and it was then cut
   mid-document. The document did not parse, so the whole trace was lost —
   strictly worse than the truncation the budget existed to perform.
   *Rule:* the budget and the limit it protects use the same unit, and the unit
   is in the field name. [SPEC-SAFE-031](../SAFETY.md#spec-safe-031).

2. **A budget whose own check was quadratic.** The size check re-serialised the
   whole accumulated document at every step: 2.0 s at 533 steps, 46.7 s at 2500
   steps, against a 15 s budget. The step limit became unreachable, so every
   long trace died by timeout *inside the measuring code*, and the student got
   an error where a truncated trace was correct.
   *Rule:* a budget check is O(1) or O(new data), never O(total).
   [SPEC-PERF-020](../PERFORMANCE.md#spec-perf-020).

A budget is a safety mechanism. A safety mechanism that can destroy the artefact
it protects is a defect, not a trade-off.

## Consequence for changing a default
A change to any value in [SAFETY.md](../SAFETY.md) §4 requires a recorded
measurement in the change ([SPEC-PERF-032](../PERFORMANCE.md#spec-perf-032)).
The quadratic check above survived review because its cost was assumed rather
than measured.

## Validation
Wrong if the reference exercises routinely reach a budget, which would mean the
defaults are teaching limits rather than runaway limits. Measure: the share of
fixture runs that carry any truncation record. A reference solution that reaches
one is a defect in the exercise
([SPEC-EX-051](../EXERCISE-SPEC.md#spec-ex-051)), until it happens often enough
to be a defect in the default.
