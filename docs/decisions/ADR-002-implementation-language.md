# ADR-002: Odin for everything except extraction

**Status:** accepted
**Date:** 2026-08-04

## Context
The project wants to be written in Odin, both because it teaches Odin and
because a tool written in its own subject is good evidence that the subject is
usable.

Extraction — reading a stopped process's frames and typed locals — needs four
capabilities: process control, debug-information parsing, location-expression
evaluation, and memory reading.

## Options

**A. Everything in Odin, including a native debugger.**
Odin can do all four on Linux. `ptrace` is reachable through the Linux syscall
bindings; ELF and DWARF are file formats.
Cost: a DWARF reader covering compile units, subprograms, variables, the type
graph, the line table, and location expressions is a project on its own.
macOS needs Mach exception ports, not `ptrace`. Windows needs PDB, not DWARF.

**B. Odin drives an external debugger over a text protocol (GDB/MI).**
Our code stays 100% Odin.
Cost: values arrive as text and are re-parsed; every read is a round trip; and a
length read from a corrupt target is already acted on by the time we see it,
which conflicts with REQ-SAFE-002.

**C. Odin core, plus a bounded script inside the debugger.**
The script has typed access to values and enforces read-time budgets at the
read.
Cost: one component is not Odin.

## Decision
**C.** Everything is Odin except the extraction script. The non-Odin component
is bounded by OBSERVATION-SPEC.md and contains no identity logic, no encoding,
and no presentation.

## Consequences

Easy:
- The memory model, the trace, the interface, the exercises, and the validator —
  every part that carries the project's reasoning — are Odin and are tested with
  `odin test`.
- Read-time safety is enforceable where the read happens.

Hard:
- The repository contains a second language.
- Contributors to the adapter need to know GDB's Python API.

Now possible later:
- Option A becomes a *replacement adapter*, not a rewrite, because the boundary
  is a process contract. It stays optional. See ROADMAP.md Phase 7.

## Validation
This decision is wrong if the extraction script grows past roughly a thousand
lines, or starts to contain rules that belong in the model. Both are visible in
review. A yearly check: does the script still implement only OBSERVATION-SPEC?


---

## Correction, 2026-08-05
This record originally named **`core:os/os2`**. That package no longer exists;
it was absorbed into **`core:os`**. The capability is real and was measured — an
Odin program launched `gdb --version` through a pipe, read 293 bytes, and
collected exit code 0
([probe report](../../fixtures/toolchain/2026-08-05-linux-x86_64.md)) — but the
name in the plan had already expired when the plan was written.

Recorded rather than silently fixed, because it is the cheapest available
evidence for why [ADR-009](ADR-009-toolchain-pinning.md) exists.
