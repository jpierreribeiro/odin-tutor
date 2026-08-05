# ADR-009: The toolchain is a versioned dependency, not a background constant

**Status:** accepted
**Date:** 2026-08-04

## Context
The picture the tool draws is derived from debug information the Odin compiler
emits, read through a debugger. Neither is under this project's control, and
neither is stable across versions.

Two facts are in tension and both are recorded, because acting on either one
alone leads to a wrong architecture:

- Odin emits DWARF version 3, and there are public community reports of periods
  where stepping and value inspection under GDB worked poorly or not at all.
- A production system inspected during this project's research reads Odin
  structs, slices, and strings through GDB's Python API today, successfully,
  including struct fields, slice `{data, len}`, and frame walking.

The second fact does not refute the first. It shows that *some* combination
works, and it says nothing about the next one.

## Options

**A. Treat the toolchain as ambient.** Use whatever `odin` and `gdb` are on the
path.
Cost: a routine compiler update can silently degrade the picture. Nothing
detects it, and the tool keeps producing output.

**B. Support exactly one pinned combination.** Refuse everything else.
Cost: unusable in practice. A student has the Odin version their course
installed.

**C. Pin one combination for continuous integration, detect the version at
runtime, and keep an evidence-backed compatibility table.**

## Decision
**C.** [SPEC-PLAT-030](../PLATFORM-SUPPORT.md#spec-plat-030),
[SPEC-PLAT-031](../PLATFORM-SUPPORT.md#spec-plat-031),
[SPEC-PLAT-032](../PLATFORM-SUPPORT.md#spec-plat-032).

Preflight reads both versions and compares them against the table:

| Result | Behaviour |
|---|---|
| Listed as good | Continue. |
| Listed as broken | Fail with `TOOLCHAIN_UNSUPPORTED`, naming the reason. |
| Not listed | Warn, record both versions in the run report, continue. |

The third row is the one that matters. Refusing an unlisted version would make
the tool unusable on the day a new Odin is released. Continuing silently would
make it lie. Continuing with a recorded warning does neither.

## Consequences

Easy:
- A toolchain regression produces a warning and a recorded version, so a bug
  report carries the evidence needed to diagnose it.
- The compatibility table is a real artefact with real rows, gated by the probe
  suite ([SPEC-TEST-040](../TEST-STRATEGY.md#spec-test-040)).
- A probe failure is classified as an unsupported platform, not as a defect in
  this project ([SPEC-TEST-042](../TEST-STRATEGY.md#spec-test-042)).

Hard:
- The table starts **empty**. Until Phase 0 runs, the project supports nothing
  it can prove. The table in
  [PLATFORM-SUPPORT.md](../PLATFORM-SUPPORT.md) §5 is deliberately left with no
  rows rather than filled with plausible ones.
- Every claimed combination costs a probe run and a committed report.
- A cached build must be invalidated by toolchain version, not only by source
  hash. A trace produced by a different compiler is a different trace.

## Consequence for the roadmap
This decision makes **Phase 0 a validation phase, not a setup phase**. Phase 0
exists to answer whether the debug information supports the model at all, on one
combination, before any model code is written. See
[ROADMAP.md](../ROADMAP.md) and [RISKS.md](../RISKS.md) R-01 and R-04.

## Validation
Wrong if, after a year, the table has one row and no student ever hits the
"not listed" path — that would mean the version detection is dead code and the
pinning was enough. Also wrong in the other direction: if most runs land on
"not listed", the table is not being maintained and the warning has become
noise the student ignores.
