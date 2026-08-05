# ADR-014: A map is counted, not walked

**Status:** accepted
**Date:** 2026-08-05
**Supersedes:** —
**Superseded by:** —

## Context

[MEMORY-MODEL.md](../MEMORY-MODEL.md) §8 listed `map` beside slice and string as
a composite the model recognises. The 2026-08-05 probe run showed that it does
not belong there.

```
map[string]int  →  struct map[string]int, fields ['data', 'len', 'allocator']
```

No key access. No value access. Odin packs the capacity into the low bits of the
data pointer and stores keys and values in parallel arrays. Slice and string are
`{data, len}` and are read directly; a map is a runtime-internal layout that the
type does not describe.

[R-20](../RISKS.md#r-20) recorded this as an **open decision, not a defect**, and
said it needs a record. Three things now depend on it:

- [SPEC-MEM-052](../MEMORY-MODEL.md#spec-mem-052) already states the behaviour,
  and the adapter already implements it. Neither has a decision behind it.
- ROADMAP Phase 2 lists map under composite recognition, so the model is about
  to touch it.
- [CURRICULUM.md](../CURRICULUM.md) Chapter 10 holds `12b-maps` back pending this
  record.

Deciding by drift is the failure this directory exists to prevent. The behaviour
that ships should be the behaviour someone chose.

## Options

**1. Count only.** A map is recorded with its type and its entry count, and its
entries are marked `unknown`. Cheap, honest, and it loses the lesson a map is
usually used to teach.

**2. Decode the layout,** pinned to one Odin version, with a probe that fails
loudly when the layout changes. Restores the lesson. Costs a reimplementation of
a private format, per Odin version, and a new probe that must run before every
compatibility row.

**3. Drop maps from the version 1 curriculum** and say so. Honest, and it removes
the question rather than answering it — a student's own program may still contain
a map, and the tool would still have to draw something.

## Decision

**Option 1. A map is recorded with its type and its entry count. Its entries are
`unknown`. The model does not walk it.**

Option 3 is rejected because it does not actually apply: the curriculum can omit
maps, but a student's program cannot be made to. The tool must have an answer for
a map it did not expect, and that answer is Option 1 either way.

Option 2 is rejected for version 1 on the strength of the rule that outranks the
others. Decoding a private layout by hand produces **wrong pairs** when it is
wrong, and a wrong pair is exactly the plausible-but-false picture the project
exists to prevent. Worse, it fails silently on a toolchain update: the layout
changes, the decoder still produces pairs, and nothing signals that they are
garbage. A count that says "I cannot see inside this" is a smaller lesson and a
true one.

The reasoning is [ADR-008](ADR-008-unknown-over-false.md) applied without
exception. `unknown` is better than false.

## Consequences

**Easy.** The behaviour is already what the adapter does, so nothing changes in
code. `map-entries` stays a documented expected failure in the probe suite rather
than an open surprise. Phase 2 can implement composite recognition without
stopping at maps.

**Hard.** A student learning maps sees a count and no entries. That is a real gap
in the teaching, and it is written down as one rather than papered over.
`12b-maps` stays out of the curriculum.

**Now impossible without revisiting this record.** Reading a map entry, anywhere
in the tool, including "just for the count of a specific key" or "only when the
key type is a string". Any of those is Option 2 arriving one field at a time.

Phase 6 does not help here. Allocator observation answers *when memory died*, not
*how a map is laid out*, so the two are unrelated and this record does not expire
with it.

## Validation

This decision is **wrong** if either of these turns out to be true:

1. Odin gains type-level or runtime-level map iteration that a debugger can
   reach — for example an exported procedure the adapter can call, or debug
   information that describes the parallel arrays. Then Option 2 costs nothing
   like what it costs today, and the gap is no longer justified.
2. Teaching maps without their entries proves to be worse than not teaching maps
   at all. That is a judgement about pedagogy, and
   [TEST-STRATEGY.md](../TEST-STRATEGY.md) §9 places it with a human reviewer.
   This record does not claim to have made it.

The probe that would notice the first is `map-entries`, which already runs in
[`probes/`](../../probes/) and already reports the type's fields on every run. If
that list ever grows, this record is due for review.
