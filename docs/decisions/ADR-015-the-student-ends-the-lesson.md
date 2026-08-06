# ADR-015: A solved exercise waits for the student

**Status:** accepted
**Date:** 2026-08-05
**Bears on:** [SPEC-EX-020](../EXERCISE-SPEC.md#spec-ex-020), ROADMAP Phase 5b

## Context
When every assertion of an exercise passes, something has to decide that the
lesson is over. Two behaviours were possible, and the tool had one of them
without anyone having chosen it: it printed `Done. Moving on.` and opened the
next exercise immediately.

That behaviour was not designed. It was what the first version of the loop
happened to do, and it survived because nothing in the plan asked the question.
The question surfaced only when `rustlings` was put beside this tool: it says
`Exercise done ✓` and then waits for `n`, so a solved exercise stays open.

This is not a gap in a feature list. Both behaviours are complete, and they
disagree about **who owns the moment after a pass**.

## Options

**A. Advance as soon as it passes.**
One less keypress, and the student is never left wondering what to do next.

Cost: it throws away the only moment this project exists for. The exercise has
just been built and traced; the picture of memory is on disk and one keypress
away. The student who wants to change one line and watch a slice's length move
with it — the thing a compile-error tutorial cannot offer at all — finds the
exercise already gone. The tool decided the lesson was over because the
assertions were satisfied, which is a statement about the assertions and not
about the student.

**B. Wait for `n`.**
The pass is announced, the reference solution is pointed at, and the loop keeps
watching the file. Saving again re-runs it. `t` still opens the picture. The
exercise ends when the student says it ends.

Cost: one keypress per exercise, and a student who does not read the screen may
sit on a solved exercise wondering why nothing happened. The key bar answers
that: `n:next` appears only once the exercise passes, so the moment the option
exists it is on screen.

## Decision
**B.** A pass is evidence that the assertions are satisfied. It is not evidence
that the student is finished looking, and only one of those two is a reason to
take the screen away.

The one place the tool advances by itself is when there is no terminal to ask —
a pipe, a test, a CI job. It says so on the line where it does it, rather than
behaving differently in silence.

## Consequences
- The keys `n` and `t` are on the same bar, and both are live on a solved
  exercise: comparing your answer against the reference and watching your own
  run are the same activity.
- `Solution for comparison:` has somewhere to be printed. Under A it would have
  been printed onto a screen that was about to be replaced.
- Progress is recorded when `n` is pressed, not when the assertions pass. A
  student who quits on a solved exercise sees it again — which is right: they
  never said they were done with it.

## What would prove this wrong
Students reporting that they press `n` without reading, every time, and that the
solved screen is noise between exercises. That would mean the moment this
decision protects is not one anybody wants, and the keypress buys nothing.
