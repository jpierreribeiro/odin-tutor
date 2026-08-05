# ADR-005: Keyframe plus delta, not full snapshots

**Status:** accepted
**Date:** 2026-08-04

## Context
Every step holds a picture of memory. 2500 steps at about 4 KB each is about
10 MB if each step is stored whole. The tool is local, so there is no wire
budget and no transfer cost. Size alone does not force a choice here.

Two operations do. The step player jumps to an arbitrary step, and it moves
backward. Both are primary, not occasional.

## Options

**A. Full snapshots.** Each step stores its whole picture.
Cost: about 10 MB and the highest serialisation cost. Correct by construction.

**B. Pure delta.** Each step stores what changed since the previous step.
Cost: reaching step *n* replays *n* steps. One wrong delta corrupts every later
step.

**C. Keyframe plus delta.** A keyframe at least every `K` steps, deltas between.
Cost: two step kinds, and a materialisation rule that must be tested.

The full comparison is in [TRACE-SPEC.md](../TRACE-SPEC.md) §2.

## Decision
**C**, with `K = 32`.

Two properties decided it, and neither is size:

1. **Random access is bounded.** A jump applies at most 31 deltas of a small
   object. This is what keeps [SPEC-PERF-010](../PERFORMANCE.md#spec-perf-010)
   reachable.
2. **Corruption is contained.** A wrong delta damages at most one keyframe
   interval. For a tool whose product is trust, "one bad step poisons the rest
   of the run" is the worst available failure mode.

A prior system used pure delta successfully, but it delivered a trace over a
network to a consumer that materialised forward from step 0. The pressure that
justified pure delta there does not exist here.

## Consequences

Easy:
- Backward navigation and jumps are cheap.
- `K = 1` yields full snapshots, so the format includes its own debugging mode.
  A test materialises every fixture at `K = 32` and at `K = 1` and requires the
  same result ([SPEC-TRACE-002](../TRACE-SPEC.md#spec-trace-002)).

Hard:
- A consumer must implement materialisation. A naive reader cannot treat step
  *n* as self-contained.
- Two step kinds means two code paths in every producer and consumer.

Impossible without revisiting this record:
- Streaming the trace to a consumer that starts reading at an arbitrary offset
  without an index.

## Validation
Wrong if measurement shows `K = 32` does not hold
[SPEC-PERF-010](../PERFORMANCE.md#spec-perf-010) on the largest fixture, or if
full snapshots at the real observed step size cost less than the complexity
saves. Phase 0 records both numbers: bytes per step, and materialisation time at
`K = 32`.

`K` is a configured number, so being wrong about the value costs a default
change, not a format change. Being wrong about the *shape* costs a format
version.
