# ADR-016: The trace carries the deaths the program reported

**Status:** accepted
**Date:** 2026-08-06
**Completes:** [ADR-011](ADR-011-absence-is-not-evidence.md)

## Context
[ADR-011](ADR-011-absence-is-not-evidence.md) settled that **absence from the
reachable set is not evidence of death**: an object leaves the picture when it
is freed, and equally when the last name for it goes out of scope, and equally
when a budget cuts the frame that held it. The model must not treat those as the
same fact, so it treats none of them as death.

That left the model with **no way to say anything died at all** — and Phase 6a
had already gathered the one fact that can say it. The adapter breaks on the
free path and reports the addresses the program handed back. Assembly used those
addresses to advance the epoch and then dropped them on the floor.

The cost showed up in the curriculum. `defer` could not be an exercise: the
right answer and the leak print the same thing, show the same picture, and end
with the same empty OBJECTS panel. Everything a student needs to see was
observed and then discarded.

## Options

**A. Leave it.** Deaths remain internal to identity.
Cost: the tool observes a fact, uses it, and cannot report it. `defer`, `free`,
and ownership generally stay unteachable, which is a large hole in a course
about a manual-memory language.

**B. Infer death from disappearance.** Treat an object leaving the picture as a
death.
Cost: exactly what ADR-011 forbids, and for the reason measured there — a
budget would produce a death, and the student would read a leak as tidy or a
tidy program as a leak depending on the display configuration.

**C. Carry the reported deaths into the trace.** A step gains `died`: the
identities the program returned to the allocator at that step.

## Decision
**C.** A free is positive evidence and it is the only positive evidence
available. It goes in the trace, it goes on the screen, and an exercise can
assert on it.

The field is optional, so the trace format version does not change
([SPEC-TRACE-070](../TRACE-SPEC.md#spec-trace-070) — adding an optional field is
not a breaking change, and a consumer that does not know it ignores it).

Three details are deliberate:

- **The identity is looked up, never minted.** A free at an address this tool
  never observed is a free of memory it never drew. Inventing an identity for it
  would put an object on screen that never existed, so such a free is counted by
  the epoch and named by nothing.
- **The screen says it in words** — `GIVEN BACK TO THE ALLOCATOR AT THIS STEP` —
  rather than by an object quietly vanishing, which is the ambiguous event this
  ADR exists to separate.
- **`frees(n)` is a whole-run predicate.** The question a student's exercise asks
  is "did this program give back what it took", not "at which step".

## Consequences
- `31-defer` exists. Its leak is rejected with *0 storages were given back*,
  while printing exactly what the right answer prints.
- The model can now distinguish "gone" from "dead", which it could not before,
  and the two have different words on screen.
- What is still NOT claimed: that a leak is detected in general. This reports
  what the program told the allocator. Memory that is never freed and never
  reported is simply memory nothing said anything about — and
  [R-21](../RISKS.md#r-21) still stands: use-after-free is not detectable by
  reading.

## What would prove this wrong
An allocator the adapter cannot break on — a student's own, or one the Odin
runtime routes around — would make `frees` silently report 0 for a correct
program. That is a false negative in the direction of accusing the student, and
it would mean the predicate needs the allocator to be identified rather than
assumed.
