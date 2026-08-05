# ADR-007: Labels and identifiers, not drawn arrows

**Status:** accepted
**Date:** 2026-08-04

## Context
The reference model for this kind of tool draws boxes joined by arrows, and the
arrows are the teaching device: two arrows to one box *is* the explanation of
aliasing.

The target here is a terminal. A terminal is a character grid. Arrow drawing in
a grid requires a graph layout: assign columns, route edges, avoid crossings,
reflow on resize, and handle a cyclic graph.

## Options

**A. Draw arrows with box-drawing characters.** Faithful to the reference model.
Cost: a layout engine, per-terminal-width reflow, unreadable output at 80
columns with more than a few objects, and a hard degradation story for a
terminal without Unicode.

**B. Name every object, and print the name at every reference.** A variable
shows `→ ②`. The object panel shows `② []int (3)`. Aliasing appears as two
variables showing `→ ②`.

**C. Draw arrows for the simple cases and fall back to labels.** Two renderers.

## Decision
**B.**

The information content is identical. "Two names refer to the same object" is
carried exactly as well by two identical labels as by two arrows, and the label
survives every terminal width, every terminal without Unicode, a screen reader,
a pasted transcript, and a golden test that compares text.

**C is rejected** because two renderers means two chances to draw a different
lie, and the fallback path would be exercised rarely and therefore be the wrong
one.

## Consequences

Easy:
- Layout is columns and lists. No graph algorithm, no reflow logic, no crossing
  minimisation.
- A cycle is trivial: the field shows the identifier of the object it is inside.
  No special case, no infinite expansion.
- The rendered screen is text, so a golden test asserts the picture directly.
- ASCII mode and monochrome mode lose nothing
  ([SPEC-TUI-040](../TUI-SPEC.md#spec-tui-040)).

Hard:
- The student must follow an identifier with their eye instead of a line. This
  is a real cost for a first-time learner and this record does not pretend
  otherwise.
- Two distinct relations — *aliasing* (two names, one object) and *shared
  storage* (two views over one buffer) — must be visually distinguished by
  marks rather than by line shape.
  [SPEC-TUI-020](../TUI-SPEC.md#spec-tui-020) requires distinct marks, because
  collapsing them reintroduces the sub-slice lie at the presentation layer.

Impossible without revisiting this record:
- A graphical front end reusing this renderer. It would reuse the *trace*, which
  carries the identities, and draw its own arrows. That is the intended path,
  and it is why the identity lives in the trace rather than in the renderer.

## Validation
Wrong if students in testing consistently fail to see aliasing on screen when
they can see it in a drawing of the same program. The measurement is a
comprehension question on the `two-equal-lists` and `sub-slice` fixtures, not an
opinion about which looks better.
