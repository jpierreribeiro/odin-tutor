# ADR-011: Absence from the observed reachable set is not evidence of death

**Status:** accepted
**Date:** 2026-08-05
**Refines:** ADR-008
**Resolves:** REVIEW.md C-2

## Context
The epoch decides when two storages at one address are two different storages
([SPEC-MEM-040](../MEMORY-MODEL.md#spec-mem-040)). Version 1 does not observe the
allocator, so it infers the epoch from what it can see.

The original rule advanced the epoch when an address left the reachable set for
at least one step and then came back. That inference is wrong in a specific way:
**the reachable set is not a property of the program. It is a property of our
traversal.** The traversal is bounded by budgets, so an object can vanish from
it while still alive.

The concrete failure:

```odin
// list: a → b → c, mid-splice
a.next = c     // only `tmp` still refers to b
               // ...and the frame holding `tmp` was cut
               //    by the objects_per_step budget
a.next = b     // b comes back
```

`b` never died. It ceased to be *visible* for one step, because of a **display
budget**. Under the original rule its identity changed: the student reads a
death and a birth where there was a splice, and the cause was a configuration
value they cannot see.

## Options

**A. Keep the rule as written.**
Cost: a budget can change an identity. This violates
[REQ-MEM-002](../REQUIREMENTS.md#req-mem-002) outright, and it makes identity
depend on presentation configuration, which contradicts the spirit of
[REQ-TRACE-006](../REQUIREMENTS.md#req-trace-006).

**B. Delete the rule. Advance the epoch only on a type change.**
Cost: `free(node); node = new(Node)` — the most ordinary manual-memory teaching
sequence there is — would always show a mutation instead of a death and a birth.
This trades a rare wrong picture for a common one.

**C. Guard the rule. Absence counts only when the observation was complete.**
Cost: the model must know, per step, whether anything was truncated. It already
does: [REQ-SAFE-005](../REQUIREMENTS.md#req-safe-005) requires every truncation
to be recorded at the step.

## Decision
**C.**

The epoch advances on absence **only if every step in which the address was
absent carries no truncation record of any kind**. A truncated step is an
incomplete observation, and an incomplete observation is not evidence.

This is [ADR-008](ADR-008-unknown-over-false.md) applied to identity rather than
to values. "Unknown is better than false" means the model must distinguish *I
saw it go* from *I stopped looking*. The original rule conflated them.

**B was rejected on frequency.** Both errors are wrong pictures, but B's error
fires on the exact program a lesson about `free` is built around, and C's
residual error fires only where the tool already told the student it truncated.

## Consequences

Easy:
- A budget can no longer change an identity. This is now a testable invariant,
  not an intention: [SPEC-MEM-044](../MEMORY-MODEL.md#spec-mem-044).
- The `truncated-then-restored` fixture asserts it directly, and it joins the
  anti-lie suite.

Hard:
- **[R-07](../RISKS.md#r-07) widens slightly.** An object that is freed during a
  step that also truncated now keeps its identity. That case was previously
  caught by accident. It is now knowingly not caught, which is the better of the
  two states.
- The epoch rule now depends on the truncation record, so a defect that fails to
  record a truncation becomes a defect in identity. The schema invariant in
  [MEMORY-MODEL.md](../MEMORY-MODEL.md) §10 covers this.

## The residual, stated plainly
One case is still not covered: a live object whose only reference sits in a
register with no DWARF variable describing it — a compiler temporary in the
middle of an expression. The tool cannot see that reference, does not truncate,
and therefore advances the epoch.

Two facts bound it, and neither removes it:

1. DWARF location expressions describe register-resident *variables*, so a
   normal local in a register is read through the ordinary path. The gap is
   limited to unnamed temporaries.
2. The build disables optimisation, so most temporaries occupy stack slots that
   DWARF describes. This is already the planned build for an unrelated reason
   ([R-04](../RISKS.md#r-04) mitigation 3).

The residual is recorded rather than closed. Closing it needs the allocator
event stream, which is Phase 6.

## Validation
Wrong if the `free-then-allocate` family of fixtures shows that the guard
suppresses epoch advance in the common teaching case rather than the rare one.
The measurement: across the fixture corpus, count the steps where an address
disappeared *and* the step was truncated. If that count is not near zero, the
budgets are too tight, not the rule too weak.
