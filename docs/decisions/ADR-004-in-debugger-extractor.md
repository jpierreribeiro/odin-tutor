# ADR-004: A script inside GDB, not GDB/MI over a pipe

**Status:** accepted
**Date:** 2026-08-04
**Refines:** ADR-002

## Context
Having decided to use a debugger (ADR-002), two ways exist to talk to GDB.

## Options

**A. GDB/MI over a pipe.** GDB's machine interface is a documented, stable,
line-oriented protocol. The Odin process would drive it with `os2.process_start`
and pipes, keeping our code 100% Odin.

**B. A Python script running inside GDB.** GDB embeds Python and exposes typed
value and type objects.

## Comparison

| | A: MI | B: in-process script |
|---|---|---|
| Our code 100% Odin | yes | no |
| Typed value access | no; text, re-parsed | yes |
| Round trips per step | many | none |
| Validate a length **before** it sizes a read | no | yes |
| Sensitivity to output formatting changes | high | low |

## Decision
**B.**

The deciding row is the fourth. REQ-SAFE-002 requires a length read from a
possibly-corrupt target to be validated *before* it controls a read. Over MI the
value arrives already rendered: the read has happened. The check would be after
the fact, which is not a check.

The other rows reinforce the choice but would not have decided it alone.

## Consequences

Easy:
- Safety rules live where the read is.
- No fragile parsing of debugger output.

Hard:
- GDB must be built with Python. Preflight checks this.
- The adapter is not Odin, which is the cost accepted in ADR-002.

## Validation
Wrong if a future GDB removes or destabilises the Python API, or if the script
proves impossible to keep small. Watch: the script's line count, and whether
`gdb --configuration` reports Python on the platforms in the matrix.
