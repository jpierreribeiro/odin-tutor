# ADR-010: Direct ANSI output, no terminal framework

**Status:** accepted
**Date:** 2026-08-04

## Context
The interface needs an alternate screen, cursor positioning, colour, line
clearing, and single-key input without line buffering. In most languages a
mature library provides these.

Odin's ecosystem is young. There is no terminal interface library with the
maintenance history, platform coverage, and adoption that would make it a safer
choice than the code it replaces.

## Options

**A. Adopt an existing Odin terminal library.**
Cost: a dependency evaluated against [AGENT-GUIDE.md](../AGENT-GUIDE.md) Rule 10
— purpose, version policy, platform availability, failure behaviour, licence,
replacement strategy — for a component whose whole job is a few dozen escape
sequences. If it stops being maintained, the interface is stranded.

**B. Bind a C library such as ncurses.**
Cost: a native dependency, a build step on every platform, and a foreign
function boundary in the one component that has no hard problem in it.

**C. Write the ANSI sequences directly.**
Cost: the sequences, the terminal mode control, and the restoration logic are
this project's to maintain.

## Decision
**C.** [SPEC-TUI-060](../TUI-SPEC.md#spec-tui-060).

The deciding fact is that [ADR-007](ADR-007-labels-not-arrows.md) already
removed the hard part. The layout is columns and lists. There is no widget
system, no focus model, no mouse handling, and no event loop beyond "read a key,
redraw". A framework would be carrying a large abstraction to save a small
amount of code.

The ANSI subset is small and is written in one place in the code:

| Need | Mechanism |
|---|---|
| Alternate screen | `?1049h` / `?1049l` |
| Cursor position | `CUP` |
| Clear line | `EL` |
| Colour | SGR, 16 colours only |
| Cursor visibility | `?25h` / `?25l` |
| Raw key input | platform terminal mode control |

Sixteen colours, not 256 and not true colour, because colour is decoration
([TUI-SPEC.md](../TUI-SPEC.md) §1) and a wider palette buys nothing that the
monochrome mode must not already convey.

## Consequences

Easy:
- One fewer dependency, and the tool stays close to "as much Odin as realistic"
  ([ADR-002](ADR-002-implementation-language.md)).
- Terminal restoration is ours, so we can guarantee it on the error path and on
  a signal, which is the failure that makes a tool unforgivable
  ([SPEC-TUI-061](../TUI-SPEC.md#spec-tui-061)).

Hard:
- Terminal mode control is platform code. It is small, and it is the only
  platform code in the interface.
- No terminal capability database. The tool assumes a baseline and degrades by
  configuration ([SPEC-TUI-040](../TUI-SPEC.md#spec-tui-040)), not by detection.
  A terminal that does not honour the baseline is handled by the ASCII and
  monochrome modes, not by a capability query.

## Validation
Wrong if the ANSI handling grows past roughly 300 lines, or if it starts
accumulating per-terminal special cases. Either signal means the interface has
outgrown the assumption behind this record, and a framework — or a smaller
interface — should be reconsidered.
