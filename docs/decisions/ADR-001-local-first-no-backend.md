# ADR-001: Local first. No backend, no sandbox.

**Status:** accepted
**Date:** 2026-08-04

## Context
An existing hosted system traces Odin programs for a teaching product. It has a
server, an authenticated API, and a hardened sandbox, because it executes code
that arbitrary internet users submit.

This project has a different user: a student, running their own program, on
their own machine.

## Options

**A. Reuse the hosted shape.** A local client talks to a server that compiles
and traces.
Cost: deployment, authentication, privacy of student code, network dependence,
and an operating cost. Buys: no local toolchain needed.

**B. Local only.** The tool runs the compiler and the debugger on the student's
machine.
Cost: the student must install the Odin toolchain and a debugger. Platform
support becomes the project's problem.

**C. Local, with an optional remote fallback.**
Cost: both of the above, plus the branch between them, forever.

## Decision
**B.** The tool is local. There is no server, no database, no hosted runner, and
no network access of any kind.

A consequence follows immediately: **there is no security sandbox**. The student
already controls the machine and could run the program directly. A sandbox would
protect the student from the student, and would imply a guarantee that does not
exist.

## Consequences

Easy:
- No deployment. No accounts. No privacy question: nothing leaves the machine.
- No hostile-code threat model, so the design can spend its attention on
  correctness of the picture instead of on containment.
- Offline use, which suits a classroom with poor networking.

Hard:
- Platform support becomes a first-class problem. See PLATFORM-SUPPORT.md.
- The student must install a toolchain.
- Diagnosing a student's failure means diagnosing their machine.

Now impossible without revisiting:
- Sharing a trace by link.
- Telemetry of any kind.
- A classroom dashboard.

## Validation
This decision is wrong if the toolchain installation burden stops students from
using the tool at all. The signal would come from the first classroom trial: if
setup takes longer than the first exercise, option A deserves reconsideration
for a hosted *companion*, not as a replacement.
