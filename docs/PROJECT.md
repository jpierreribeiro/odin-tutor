# PROJECT

Project charter. This document states the purpose, the scope, and the limits.

## 1. Purpose

Odin is a manual-memory language. Its hardest concepts for a learner are not
syntax. They are:

- what a slice is, and how it differs from the array behind it;
- when two names refer to one thing;
- what `new` and `free` do to memory;
- what a pointer denotes;
- what happens to a stack frame during a call and a return.

Text output cannot show these. A diagram can.

This project builds a terminal tool that shows them.

## 2. Product statement

`odin-tutor` is a local command-line program. It has two modes.

**Inspect mode.** The student gives a `.odin` file. The tool shows the execution
of that file, step by step.

**Exercise mode.** The tool presents an ordered set of exercises. Each exercise
states a goal in terms of the *picture*, not only in terms of the output. The
tool checks the student's solution against the recorded execution.

An exercise goal can be:

    Make `b` refer to the same list as `a`.
    Now make `b` a copy. The picture must show two objects, not one.
    Build a chain of four nodes. The picture must show four objects
    and three references.

## 3. What makes this different from existing tools

| Tool | What it does | What it does not do |
|---|---|---|
| Python Tutor | Shows execution state for several languages, in a browser | No Odin. Not local. Not exercise-driven. |
| Rustlings | Ordered exercises, compile-error driven, local CLI | No execution visualisation at all. |
| GDB / LLDB | Full debugger control | No pedagogical model. No object graph. Requires the student to already know what to ask. |

This project takes the visual model from the first, the local exercise loop from
the second, and uses the third as an implementation mechanism.

## 4. Primary user

A student who is learning Odin, or learning systems programming through Odin.
The student can use a terminal. The student cannot yet use a debugger.

## 5. Secondary user

An instructor who writes exercises. The instructor needs the assertion language
in [VALIDATION-SPEC.md](VALIDATION-SPEC.md) to state what a correct solution
looks like.

## 6. In scope for version 1

- One platform: Linux on x86-64. See [PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md).
- One debugger: GDB.
- Single-file Odin programs.
- Bounded traces of short programs.
- A terminal user interface with forward and backward navigation.
- An exercise format and a validator.

## 7. Explicitly out of scope for version 1

Each item below is excluded on purpose. Each has a reason.

| Excluded | Reason |
|---|---|
| Any server, backend, database, or hosted runner | The tool runs the student's own code on the student's own machine. A server adds deployment, authentication, and privacy problems that buy nothing here. See [ADR-001](decisions/ADR-001-local-first-no-backend.md). |
| A security sandbox around the student's program | The student already controls the machine. A sandbox would protect the student from the student. The *tracer* still defends itself — see [SAFETY.md](SAFETY.md). See [ADR-001](decisions/ADR-001-local-first-no-backend.md). |
| macOS and Windows support | The debug mechanism differs per platform and is not a build flag. See [PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md). |
| Multi-file Odin packages | Frame filtering and source display both become harder. Add after the single-file case is correct. |
| Concurrency, threads, `core:thread` | The trace model assumes one thread of execution. Multi-thread tracing is a different design. |
| A web user interface | The trace format is designed to allow one later. Building one now would divide attention. |
| Editing code inside the tool | The student uses their own editor. The tool watches the file. |
| Teaching languages other than Odin | The memory model in this repository is Odin's. |

## 8. Success criteria for version 1

The project succeeds when all of the following are true.

1. A student can run `odin-tutor inspect main.odin` on Linux and step through
   the execution of a program that uses a struct, a slice, and a procedure call.
2. The picture is correct for every fixture in
   [TEST-STRATEGY.md](TEST-STRATEGY.md) §5.
3. No fixture produces a value, an identity, or a relationship that is wrong.
   A fixture may produce `unknown`. It may not produce a lie.
4. Ten exercises exist, and the validator accepts a correct solution and rejects
   a plausible incorrect one for each.

Criterion 3 is the one that can fail silently. [TEST-STRATEGY.md](TEST-STRATEGY.md)
§4 exists to make it fail loudly.

## 9. Non-goals that look like goals

**Speed of trace generation is not a goal.** Tracing under a debugger is slow.
A short exercise is expected to take seconds. The budget in
[PERFORMANCE.md](PERFORMANCE.md) exists to stop it becoming minutes, not to make
it fast.

**Completeness of the memory picture is not a goal.** The tool shows what it can
show truthfully. It marks the rest. A picture with three `unknown` fields is a
better product than a picture with three invented fields.

**Feature parity with a debugger is not a goal.** There are no watchpoints, no
expression evaluation, and no editing of target memory.

## 10. Relationship to prior work

An earlier system (a hosted teaching IDE) already drives GDB over Odin and
produces a step trace. That work proves the mechanism is possible and supplies
several hard-won failure modes, which appear in this repository as requirements
rather than as anecdotes. See [RISKS.md](RISKS.md) §4.

This project does not reuse that code. The constraints differ: that system is
hosted and must sandbox hostile code, and its trace crosses a network. This one
is local and neither applies. The design therefore diverges — most visibly in
the trace encoding decision ([ADR-005](decisions/ADR-005-trace-encoding.md)).
