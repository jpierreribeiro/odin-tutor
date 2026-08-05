# ADR-012: A second thread ends the trace; it does not degrade it

**Status:** accepted
**Date:** 2026-08-05
**Resolves:** REVIEW.md §2, last row

## Context
The whole model assumes one thread. A step is "the program advanced one line,
and here is memory afterwards". With a second thread running, memory can change
between two steps with **no line of the student's code responsible**, and the
tool cannot tell which change came from where.

Nothing in the specification detected this. A threaded program would have
produced a confident, believable, wrong picture — the one outcome the project
exists to prevent.

## Options

**A. Refuse before running.** Detect thread creation in the source.
Cost: it needs static analysis of arbitrary Odin, including indirect calls. It
is not reliable, and an unreliable refusal blocks correct programs.

**B. Trace anyway, with a warning banner.**
Cost: the banner says "some of this may be wrong" and cannot say which part.
[AGENT-GUIDE.md](../AGENT-GUIDE.md) §6 lists exactly this shape as a tempting
change that is not an improvement.

**C. Trace until the second thread appears, then stop with a terminal
condition.**
Cost: a partial trace, and a runtime detection path in the adapter.

## Decision
**C.**

The adapter subscribes to the debugger's **thread-creation event**. The moment a
thread other than the initial one is created, tracing stops. The tool
produces a **valid trace of everything up to that point**, plus the terminal
condition `TARGET_BECAME_MULTITHREADED`.

This is the same shape the project already uses for every budget
([ADR-006](ADR-006-budgets.md)): stop, produce a valid document, record why,
show it to the student. A thread is not a budget, but the honest behaviour is
identical — the tool stops where its claims stop.

**A was rejected** because it cannot be done reliably, and a false refusal is
worse than a partial trace.
**B was rejected** because an unlocatable warning is not a degradation, it is a
disclaimer. A student cannot act on "part of this picture may be false".

## Why not simply keep tracing the main thread
Because the picture is not about one thread. It is about *memory*, and memory is
shared. Every value the tool reads after the second thread starts may have been
written by code the student cannot see in the frames column. Every one of them
would be drawn as if the shown line produced it.

## Consequences

Easy:
- The failure is named, visible, and located at a step.
- The student keeps every step before the thread started, which is where the
  lesson usually is.
- No static analysis, and no new dependency.

Hard:
- The adapter carries an event subscription. It costs nothing on the hot path,
  which a per-stop count would not.
- The handler must ignore the initial thread, which also arrives as a creation
  event.

## Correction, 2026-08-05 — counting does not work

The first version of this record said "watches the thread list". **Measured, that
detector never fires.**

A program calling `thread.create_and_start` was stepped from start to finish.
The thread count at every stop stayed at **1**, while the program printed from
the other thread. GDB reported `[Thread 0x7ffff7bff6c0 exited]`: the thread
lived and died **between two stops**. Sampling misses it.

The event hook catches it and stops at the right place:

```
gdb.events.new_thread, ignoring thread num 1
→ recorded steps 6, 7, 8; stopped at line 8
   line 8 is `t := thread.create_and_start(...)`
```

The baseline question is also answered: a plain Odin program has exactly one
thread ([R-17](../RISKS.md#r-17)), so no refinement of the rule is needed.

Recorded rather than quietly fixed, because a per-stop count is the obvious
implementation and it would have shipped a detector that never fires — a
safeguard that is worse than none, since it reads as protection.

## Scope, stated so it is not mistaken for a plan
This does **not** make the tool a concurrency teaching tool. It makes it stop
lying about concurrency. Visualising two threads needs a different model — a
step would no longer be a total order — and that is not an increment on this
one.

## Validation
Wrong if the `spawns-thread` fixture stops at the wrong step, or if the
`thread-count` probe shows that ordinary single-threaded Odin programs already
run more than one thread, in which case the detection rule needs the refinement
above before it is useful.
