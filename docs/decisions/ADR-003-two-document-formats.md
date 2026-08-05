# ADR-003: Two document formats, not one

**Status:** accepted
**Date:** 2026-08-04

## Context
The adapter produces data. Consumers need a trace. The question is whether the
adapter emits the final trace, or an intermediate form the core converts.

## Options

**A. One format.** The adapter emits the trace directly.
Cost: identity assignment, shared-storage detection, and delta encoding live in
the extraction script — in the non-Odin component, and duplicated in every
future adapter.

**B. Two formats.** The adapter emits observation records; the core emits the
trace.
Cost: two schemas to version.

## Decision
**B.**

## Consequences

Easy:
- The subtle logic lives in Odin and is unit-tested.
- A new adapter implements a small contract, not the whole model.
- **The core is testable without a debugger.** Recorded observation streams are
  fixtures, so the model, the renderer, and the validator are tested in
  milliseconds with no external tool. This is the strongest reason.

Hard:
- Two schemas, two version policies.
- A field needed by the trace must be carried by the observation record, so
  adding one touches both.

## Validation
Wrong if, after a year, the observation format has become a copy of the trace
format with different field names. The signal: a change that adds the same field
to both documents, repeatedly, with no transformation between them.
