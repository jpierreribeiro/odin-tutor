# ADR-013: Odin conventions for this repository

**Status:** accepted
**Date:** 2026-08-05

## Context
A specification set with no code leaves every small decision to whoever writes
the first line: how errors are returned, who owns an allocation, what a package
is called. Those decisions get made anyway, differently each session, and the
result is a codebase that reads as though several people wrote it who never
met.

The conventions below are **not invented here**. They are taken from
*Understanding the Odin Programming Language* by Karl Zylinski, and from the
`core` collection the book points at. Where the book states a convention, this
record follows it and cites the chapter rather than reasoning from first
principles.

## Decision

### 1. Errors are an extra return value, and always the last one
Chapter 16. Odin has no exceptions. A procedure that can fail returns its
result plus an error, error last, so that `or_else` and `or_return` work.

Which type:

| Situation | Type | Used here |
|---|---|---|
| Did it work? | `bool` | `encode` |
| A few named ways to fail | `enum` | `Decode_Error`, `Build_Error`, `Failure` |
| A failure that carries data | `union` | none yet |

Every error type in this repository is an **enum**, because no failure so far
carries data the caller acts on beyond the name. A union is correct the moment
one does.

**`or_return` is used sparingly.** The book warns against a big error union and
`or_return` everywhere: it passes every failure to the caller, including the
ones this code should handle. It appears here only in `assembly_init`, where
the caller genuinely must decide what to do about an allocation failure.

`#optional_ok` is not used. The book notes it makes a real error
indistinguishable from a zero result, and the whole project is about not
confusing those.

### 2. Naming
From the `core` collection, as the book adopts it:

| Thing | Case | Example |
|---|---|---|
| Type | `Ada_Case` | `Value_State`, `Frame_View`, `Storage_Range` |
| Enum member | `Ada_Case` | `.Not_Yet_Active`, `.Budget_Disagreement` |
| Procedure, variable, field | `snake_case` | `identity_for`, `bytes_so_far` |
| Constant | `SCREAMING_SNAKE_CASE` | `TRACE_VERSION`, `KEYFRAME_INTERVAL` |
| Package | `snake_case`, unique per program | `tutor_model` |

**Test procedures are sentences.** `a_budget_never_changes_an_identity`, not
`test_epoch_2`. The runner prints the name when it fails, and a sentence tells
the reader what broke without opening the file.

### 3. Packages
Chapter 17. A package is a folder. Cyclic dependencies are not allowed, so the
dependency order is fixed and one-way:

```
obs   ←  model  ←  render
              ↖   ↖
                tutor  →  preflight
```

The **package name** is the linker's prefix and must be unique across the whole
program, so every package here is `tutor_*` even though the folder is short.
The folder name is what an importer sees; the package name is what the linker
sees. They are allowed to differ, and here they do.

### 4. Memory
Chapters 12 and 13.

**One arena per trace.** The frames, slots, entities, and steps of a trace share
one lifetime: they are born together and die together. That is what an arena is
for. `Assembly` owns a growing virtual arena, everything it builds comes from
that arena, and `assembly_destroy` releases the whole trace in one call.

The ownership rule is written at the type, not left implicit:

> The `Trace` returned by `assemble` points into this arena. It is valid until
> `assembly_destroy`. A caller that needs the trace to outlive the Assembly
> must encode it first.

This is the book's `Level` / `destroy_level` example applied to the one place in
this project where it fits. It also keeps the test runner's leak report clean —
and a leak report that is always noisy is a leak report nobody reads.

**`context.temp_allocator` for anything that dies within one procedure**, freed
by the caller with `free_all`. Never for something returned.

**The tracking allocator is not set up in `main`.** `odin test` already runs it,
which is where it matters most.

### 5. Features not used
Chapter 23.

| Feature | Why not |
|---|---|
| `using` on a variable or parameter | The book: it makes it unclear where a name comes from. Refactoring aid, not permanent code. |
| `any` | Exists for `fmt`-like procedures. Parametric polymorphism is the answer for generic code. |
| Dynamic literals | Disabled by default, and they allocate invisibly. `slice.clone_to_dynamic` says so out loud. |

`using` **on a struct field** is a different feature and is not banned.

### 6. Build
Chapter 18. No build system. `odin build src/tutor -out:odin-tutor` and
`odin test src/<package>`. A file to be skipped carries `#+build ignore`.

`ODIN_ROOT` must be set when the compiler was not installed to a standard
prefix, or `core:` imports fail with a path error that does not mention the
variable. This cost time during Phase 0 and is written in
`fixtures/toolchain/README.md`.

### 7. Comments
The repository rule, not the book's: **a comment says why, never what.**

```odin
// THE TRAP: a size check that serialises the accumulated document at every
// step is O(n²). A prior system measured 2.0 s at 533 steps and 46.7 s at
// 2500 ... the step limit became unreachable.
```

not

```odin
// Add the cost to the total.
```

A comment that restates the line is deleted by the next reader. A comment that
records a measurement, a decision, or a trap survives — and every rule in this
project exists because something went wrong once.

Where a rule has a specification, the comment cites its identifier. That is what
makes [TRACEABILITY.md](../TRACEABILITY.md) checkable rather than aspirational.

## Consequences

Easy:
- A new agent reads one page and writes code that matches.
- The conventions are the language's, so they match `core` and every other Odin
  codebase the reader has seen.

Hard:
- The arena's ownership rule is a real constraint, and getting it wrong gives a
  use-after-free rather than a compile error. It is stated at the type for that
  reason.

## Validation
Wrong if a contributor familiar with Odin finds this document surprising.
The conventions are meant to be unremarkable; if any of them needs defending
against the book, the book wins and this record is amended.
