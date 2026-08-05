# GLOSSARY

Controlled vocabulary. Every document in this repository uses these terms with
these meanings only. Do not introduce a synonym. If a needed term is missing,
add it here first.

Writing rule: when a document uses a term from this list, it uses it exactly.
When a document needs a different meaning, it uses a different term.

## Core execution terms

**Target program**
: The Odin program that the student wrote. The tool observes it. The tool never
  trusts what it reads from it.

**Target process**
: One operating-system process that runs the target program.

**Debugger**
: An external program that controls the target process. GDB is the first one
  supported.

**Adapter**
: The component that drives the debugger and produces observation records. See
  [DEBUGGER-ADAPTER.md](DEBUGGER-ADAPTER.md).

**Core**
: The part of the tool written in Odin. It owns the trace model, the exercise
  engine, the validator, and the terminal user interface.

**Step**
: One recorded point of execution. A step corresponds to one source line of the
  target program having been reached, in a procedure that belongs to the
  student's file.

**Run**
: One execution of the target program from start to end, which produces one
  trace.

## Trace terms

**Observation record**
: What the adapter emits for one step. It is raw and pre-semantic. It contains
  addresses. It contains no logical identity. See
  [OBSERVATION-SPEC.md](OBSERVATION-SPEC.md).

**Trace**
: The complete, semantic, versioned document that the core produces from
  observation records. It contains logical identity. It contains no address as
  an identity. See [TRACE-SPEC.md](TRACE-SPEC.md).

**Keyframe**
: A step in the stored trace that carries complete state.

**Delta**
: A step in the stored trace that carries only the change since the previous
  step.

**Materialised step**
: The complete state at a step, after the core reconstructs it from the nearest
  keyframe and the deltas after it.

## Memory terms

These five terms are distinct on purpose. See
[MEMORY-MODEL.md](MEMORY-MODEL.md).

**Storage**
: A contiguous region of target memory that has a lifetime. A stack frame's
  locals, a global, and one heap allocation are each a storage.

**Object**
: A typed value that occupies a storage at an offset. A struct instance and a
  fixed array are objects.

**View**
: A triple of storage, offset, and length. An Odin slice and an Odin string are
  views. A view is not an object. Two views can share one storage.

**Pointer value**
: A value that denotes an address. It is not a reference until the core resolves
  it.

**Reference**
: A resolved link from one value to one object or one view, expressed by logical
  identity.

**Logical identity**
: A stable identifier that the core assigns, such as `obj-4`. It is what the user
  interface shows and what the validator asserts on. It is never a raw address.

**Epoch**
: A counter attached to a storage. It increases when the core observes that the
  region at an address is no longer the same region. It stops a reused address
  from silently keeping an old identity.

**Shares storage**
: The relationship between two views whose storages are the same. It is weaker
  than *alias*.

**Alias**
: The relationship between two names that resolve to the same logical identity.

## Value state terms

These four states are distinct on purpose. Never collapse them. See
[MEMORY-MODEL.md](MEMORY-MODEL.md) §5.

**not-yet-active**
: Execution has not passed the point that gives the variable its value. The
  memory holds something, but that something is not the variable's value.

**unreadable**
: The tool tried to read the memory and the read failed.

**unknown**
: The tool did not try to read, or read a value it cannot interpret truthfully.
  A safety limit produces this state.

**valid**
: The tool read the value and can state it.

## Exercise terms

**Exercise**
: A directory that contains starting source, metadata, and assertions.

**Assertion**
: One statement about the trace that must hold for the exercise to pass. See
  [VALIDATION-SPEC.md](VALIDATION-SPEC.md).

**Verdict**
: The result of evaluating an assertion. One of `pass`, `fail`, `undetermined`.

**undetermined**
: The assertion could not be evaluated, because the trace lacks the information.
  An `undetermined` verdict is not a pass.

## Limit terms

**Budget**
: A numeric limit that the tool enforces on itself, such as the maximum number of
  steps.

**Truncation**
: The state that results from reaching a budget. Truncation is always reported.
  Truncation never produces an invalid document.

**Degrade**
: To produce less information, correctly. The opposite of failing, and the
  opposite of inventing.

## Words this project does not use

| Do not write | Write instead | Reason |
|---|---|---|
| box | object, or view | "Box" is a drawing term. The model has no boxes. |
| heap (as the whole picture) | object graph | Odin has a heap. Using the same word for the picture is ambiguous. |
| variable (for a heap value) | object | A variable is a name in a frame. |
| pointer (for a resolved link) | reference | See the two entries above. |
| crash | Use the specific error class from [TRACE-SPEC.md](TRACE-SPEC.md) §8 | "Crash" hides who failed. |
| sandbox | jail (only when describing prior hosted work) | This project has no sandbox. See [SAFETY.md](SAFETY.md). |
| just, simply, easy, obviously | (delete the word) | These words hide difficulty from the next reader. |
