# MEMORY-MODEL

The rules that decide what the picture claims. This is the most important
specification in the repository. Most ways to be wrong live here.

Terms are from [GLOSSARY.md](GLOSSARY.md) and are used exactly.

---

## 1. Why a model is needed

A naive visualiser reads a value, sees an address, and uses the address as the
name of a thing. That produces four distinct lies, all of which have been
observed in a working system:

1. Two empty slices share a null data pointer, so the picture shows one object
   with two names. It teaches aliasing where there is none.
2. `b := a[:2]` shares a data pointer with `a`, so `b` is drawn with `a`'s
   length. It teaches that a sub-slice is the whole slice.
3. A local is read before its initialising line runs, so stack garbage is shown
   as the value.
4. A freed allocation's address is reused, so a new object silently inherits the
   old object's identity.

Each of these is *believable*. None of them raises an error. The model exists to
make each one impossible or, where that is not possible, explicit.

---

## 2. Entities

### Storage
A contiguous region of target memory that has a lifetime.

Kinds: `frame` (a call frame's locals), `global`, `allocation` (from the Odin
allocator), `unknown`.

A storage has a base address, a size when known, and an epoch (§7).

### Object
A typed value that occupies a storage at an offset. Struct instances and fixed
arrays are objects. An object has a type name.

### View
A triple of storage, offset, and length. An Odin slice is a view. An Odin string
is a view. A dynamic array is a view with an additional capacity.

A view is **not** an object. This distinction is the whole of §4.

### Pointer value
A value that denotes an address. It becomes a reference only after the model
resolves it (§6).

---

## 3. Identity rules

<a id="spec-mem-001"></a>
### SPEC-MEM-001 — Logical identity only
Every object and every view in the trace carries a logical identity. The trace
never uses a target address as an identity.

Identities are `obj-N`, `view-N`, `sto-N`, `frame-N`, with `N` a counter that
increases within one run.

An address MAY appear as an *attribute* of an object when the consumer asks for
an advanced view. It is never the key, never used for equality, and never shown
by default.

*Rationale:* addresses vary between runs under address-space randomisation.
An identity that varies between runs cannot be asserted on, diffed, or taught.

<a id="spec-mem-002"></a>
<a id="spec-mem-006"></a>
### SPEC-MEM-006 — Two empty views are separated by location, never by content
**Measured 2026-08-05.** Two empty slices are **byte-identical**: both are
`{data: 0x0, len: 0}`. Nothing in their contents tells them apart. Only the
address of the variable that holds each one does.

This is why the identity key includes the view's location. A key derived from
`{data, len}` alone would collapse every empty slice in a program into one
object, which is [REQ-MEM-004](REQUIREMENTS.md#req-mem-004) failing in the most
visible way possible.

### SPEC-MEM-002 — Identity is minted from a key, not from an address
The model mints a storage identity from the key:

```
(kind, base address, size, epoch)
```

It mints an object identity from:

```
(storage identity, offset, type name)
```

It mints a view identity from:

```
(storage identity, offset, length, type name)
```

When a key has been seen in this run, the identity is the one already assigned.

<a id="spec-mem-003"></a>
### SPEC-MEM-003 — Identity is stable while the entity lives
While the key holds, the identity does not change between steps. This satisfies
[REQ-MEM-002](REQUIREMENTS.md#req-mem-002).

<a id="spec-mem-004"></a>
### SPEC-MEM-004 — Value equality is never identity
Two entities with equal contents and different keys have different identities.
The model never compares contents to decide identity.

<a id="spec-mem-005"></a>
### SPEC-MEM-005 — Address equality alone is never identity
Two entities with the same base address have the same storage identity only when
the kind, the size, and the epoch also match.

---

## 4. Views, and the two bugs they cause

<a id="spec-mem-010"></a>
### SPEC-MEM-010 — A view is identified by its whole triple
Two views with the same storage and different offset or different length have
**different** view identities.

This is the sub-slice rule. For:

```odin
a := []int{10, 20, 30}
b := a[:2]
```

the model produces one storage, two views, lengths 3 and 2.

<a id="spec-mem-011"></a>
### SPEC-MEM-011 — Shared storage is a recorded relation
When two views resolve to the same storage identity, the trace records that
relation. The user interface can then state it.

This is stronger than giving them separate identities. Separate identities stop
the lie. The recorded relation teaches the truth: they are different windows on
one array. Teaching that is the point of the exercise on slices.

<a id="spec-mem-012"></a>
### SPEC-MEM-012 — A view with a null data pointer has no storage
When a view's data pointer is null, the view has no storage. Its identity is
minted from the location of the view value itself:

```
(kind="empty-view", address of the view value, type name)
```

Two empty views at different locations therefore have different identities. This
satisfies [REQ-MEM-004](REQUIREMENTS.md#req-mem-004).

*Rationale:* a null pointer denotes nothing, so it cannot name anything. Using
it as a key made two unrelated variables into one object.

<a id="spec-mem-013"></a>
### SPEC-MEM-013 — Length is validated before it is used
A view's length is read from the target. Before the model or the adapter uses it
to drive a loop or size a read, it is checked against `MAX_SANE_LENGTH`
([SAFETY.md](SAFETY.md) §4). A length outside the bound produces `unknown` for
the whole view, not a truncated view.

*Rationale:* a truncated view of a corrupt length is a lie about the length. An
`unknown` is not.

---

## 5. Value states

<a id="spec-mem-020"></a>
### SPEC-MEM-020 — Four states, never merged
Every variable slot carries exactly one state.

| State | Meaning | Cause |
|---|---|---|
| `not-yet-active` | Execution has not passed the point that gives this variable its value. | Current line is at or before the declaring line. For a parameter: current line is at or before the procedure's own line, because the prologue has not run. |
| `unreadable` | A read was attempted and failed. | Unmapped address; debugger error. |
| `unknown` | No read was attempted, or the result cannot be interpreted truthfully. | A budget was reached; a type is not supported; a length failed validation. |
| `valid` | The value was read and can be stated. | — |

<a id="spec-mem-021"></a>
### SPEC-MEM-021 — `not-yet-active` is derived from position, not from content
The model does not inspect memory to decide that a variable is not yet active.
It compares the current line with the declaring line.

*Rationale:* debug information scopes a variable to the whole frame. Scope is
not initialisation. A measured example from a working system: a local read
before its own initialiser reported `140737488344096`, which is a stack address,
not a value the student wrote.

The comparison is strict. A variable declared on line 16 is `not-yet-active`
while the current line is 16, and becomes readable at line 17.

<a id="spec-mem-022"></a>
### SPEC-MEM-022 — A frame records why it has no variables
A frame carries a flag that distinguishes:

- the procedure has no variables in scope; from
- the procedure has variables, and none is active yet.

The user interface must render these differently
([REQ-MEM-008](REQUIREMENTS.md#req-mem-008)).

*Rationale:* "no variables" at the entry step of `double(n: int)` asserts that
`double` takes no parameters. That is a stronger and falser claim than "not
readable yet".

---

## 6. Pointers

<a id="spec-mem-030"></a>
### SPEC-MEM-030 — Two resolution levels
**Level 1, lookup.** The pointer's address falls inside a storage that the model
already knows in this step. The model emits a reference to the object at that
address. No memory is read.

**Level 2, expansion.** The pointer is typed, and its target type is an
aggregate (struct, array, union). The adapter may read through it to discover
the object. Expansion is breadth-first and is bounded by
[SAFETY.md](SAFETY.md) §4.

<a id="spec-mem-031"></a>
### SPEC-MEM-031 — Unshaped pointers are never followed
The model does not read through:

- `rawptr`;
- a pointer to a procedure;
- a pointer whose target type is absent from the debug information;
- a pointer to a scalar.

Such a pointer is recorded as a pointer value with no reference. This satisfies
[REQ-MEM-010](REQUIREMENTS.md#req-mem-010).

*Rationale:* reading through a pointer with no declared shape is guessing at the
shape. The result would be a plausible object that does not exist.

A pointer to a scalar is excluded from expansion because a single scalar target
adds no structure to the picture and cannot be distinguished from a
mis-typed pointer into the middle of something else.

<a id="spec-mem-032"></a>
### SPEC-MEM-032 — Reading after a free is possible, and is NOT detectable
In a manual-memory language the tool can read a region that the program has
already freed. The model cannot detect this in version 1 (§7).

**Measured 2026-08-05.** A pointer read after `free` returned `8313165202016105638`
with **no exception**: the region stays mapped. The tool sees an ordinary
integer and has no signal at all.

By contrast, a genuinely unmapped address (`0xdeadbeef`) raises a catchable
`gdb.MemoryError`, and that is the real source of `unreadable`.

Two consequences, both stated rather than softened:

1. The tool **does not detect use-after-free**, and the documentation must not
   imply it does.
2. Observing the allocator ([ROADMAP.md](ROADMAP.md) Phase 6) is not only about
   identity. It is the **only** source of the fact that memory was freed.

[R-21](RISKS.md#r-21).

The consequence is stated plainly rather than hidden: an object shown after its
allocation was freed may not exist. Version 1 does not claim to detect it.
[RISKS.md](RISKS.md) R-07 tracks this. The mitigation path is §7.3.

<a id="spec-mem-033"></a>
### SPEC-MEM-033 — Null is shown as the source-level value
A null pointer renders as `nil`, not as `0x0`.

*Rationale:* `nil` is what the student wrote. `0x0` is a machine detail that
invites the student to think about representation when the lesson is about
absence.

---

## 7. Allocation identity and address reuse

This section states a requirement that version 1 does **not** fully meet, and
says so.

<a id="spec-mem-040"></a>
### SPEC-MEM-040 — Epoch
Every storage carries an epoch. Two storages with the same address and different
epochs are different storages, and therefore produce different identities.

<a id="spec-mem-041"></a>
### SPEC-MEM-041 — What increases the epoch in version 1
The model increases the epoch when either holds:

1. the type observed at an address differs from the type previously observed
   there;
2. the address was absent from the reachable set for at least one step and then
   reappeared, **and no step in which it was absent carries a truncation
   record**.

The guard on rule 2 is not a detail. Without it, a display budget changes an
identity. See [SPEC-MEM-044](#spec-mem-044) and
[ADR-011](decisions/ADR-011-absence-is-not-evidence.md).

<a id="spec-mem-042"></a>
### SPEC-MEM-042 — What version 1 cannot detect
Version 1 does not observe the allocator. It therefore cannot detect the case
where:

- an allocation is freed, and
- the allocator immediately returns the same address for a new allocation, and
- the new allocation has the same type, and
- either the address never leaves the reachable set, or it leaves it only during
  steps that carry a truncation record.

In that case the new object inherits the old identity. The effect is that the
picture reports a mutation where it should report a death and a birth. It does
not fabricate a value, and it does not leak an address.

This is a **known incorrectness**. It is listed in
[RISKS.md](RISKS.md) R-07 and in
[TRACEABILITY.md](TRACEABILITY.md) as a partly-met requirement.

<a id="spec-mem-043"></a>
### SPEC-MEM-043 — The path to detecting it
Observing the allocator would close the gap. The adapter would place breakpoints
on the Odin runtime's allocation and free entry points and record an allocation
event stream. That stream would drive the epoch exactly.

This is deferred because:

- it multiplies the number of debugger stops, which costs time
  ([PERFORMANCE.md](PERFORMANCE.md));
- the Odin allocator is selected through `context.allocator`, so the entry point
  is not a single fixed symbol;
- it needs its own validation on each toolchain version.

It is [ROADMAP.md](ROADMAP.md) Phase 6 and it is a stated non-goal of version 1.

<a id="spec-mem-044"></a>
### SPEC-MEM-044 — A budget never changes an identity
Reaching any budget SHALL NOT change the identity of any entity. Absence from
the observed reachable set is absence of evidence, not evidence of death.

This is the identity form of [ADR-008](decisions/ADR-008-unknown-over-false.md).
The model must distinguish *the reference was overwritten* from *the traversal
stopped early*, and only the first is evidence.

**Test:** the `truncated-then-restored` fixture. An object leaves the observed
set because a budget cut the frame that referred to it, and comes back at the
next step. Its identity is equal before and after. This is an anti-lie test
([SPEC-TEST-020](TEST-STRATEGY.md#spec-test-020)).

**One case remains uncovered.** A live object whose only reference sits in a
register that no DWARF variable describes — an unnamed temporary inside an
expression — is invisible without any truncation being recorded, so rule 2 still
fires. Two things bound it and neither removes it: DWARF describes
register-resident *variables*, so ordinary locals are read normally; and the
build disables optimisation, so most temporaries occupy described stack slots.
The residual closes with the allocator event stream, in Phase 6.

---

## 8. Composite Odin types

<a id="spec-mem-050"></a>
<a id="spec-mem-053"></a>
### SPEC-MEM-053 — Map is not in the same class as slice and string
**Measured 2026-08-05.** A map's type exposes `['data', 'len', 'allocator']`.
There is **no key access and no value access**. Odin packs the capacity into the
low bits of the data pointer and stores keys and values in parallel arrays.

Slice and string are `{data, len}` and are read directly. Listing `map` beside
them was wrong.

Version 1 default, until an ADR decides otherwise: a map renders as
`map (N entries)` with the entries marked `unknown`, by
[SPEC-SAFE-011](SAFETY.md#spec-safe-011). Showing an entry decoded from a layout
that no type describes is a guess, and a guess is what this document forbids.

[R-20](RISKS.md#r-20) carries the open decision.

### SPEC-MEM-050 — Semantic recognition precedes structural rendering
Odin's slice, string, and dynamic array appear in debug information as structs.
The model recognises them by type name **before** the generic struct path.

| Type shape | Rendered as | Not rendered as |
|---|---|---|
| `string` | `"Ana"` | `{data, len}` |
| `[]T` | the elements | `{data, len}` |
| `[dynamic]T` | the elements, with capacity available | `{data, len, cap, allocator}` |
| `map[K]V` | see SPEC-MEM-052 | invented pairs |

<a id="spec-mem-051"></a>
### SPEC-MEM-051 — The representation stays available
The internal representation is not deleted. A consumer may request it. The
default view does not show it.

*Rationale:* the student eventually needs to learn that a slice is a pointer and
a length. The tool should be able to teach that on demand. It should not lead
with it.

<a id="spec-mem-052"></a>
### SPEC-MEM-052 — Maps are reported honestly, not walked
Odin's map stores its data in a runtime-internal layout. The model does not walk
it. A map is recorded with its type and its entry count, marked as not expanded.

*Rationale:* reproducing a runtime-internal layout means reproducing a private
format. Getting it wrong shows wrong pairs, which is worse than showing none.
Walking it correctly makes the tool break on a toolchain update, silently.

---

## 9. Frame identity

<a id="spec-mem-060"></a>
### SPEC-MEM-060 — A frame is not a stack position
A frame identity distinguishes two invocations that occupy the same stack
position at different times.

The key is:

```
(return address in the caller, caller's stack pointer, procedure name)
```

*Rationale:* `fib(n-1) + fib(n-2)` places two calls on one source line. The
debugger enters and leaves the first without stopping at the caller's level, so
stack depth never changes and firing order does not say which invocation
returned. Two calls on one line are two call sites, so two return addresses.
Sibling invocations reuse a stack position but never at the same time, so the
most recent frame with a given key is the right one.

<a id="spec-mem-061"></a>
### SPEC-MEM-061 — An unresolvable frame identity withholds the return value
When the model cannot determine which invocation a return value belongs to, it
records `unknown`. It does not record a value.

*Rationale:* a measured failure from a working system: a frame holding `n = 0`
reported that it returned 8, which is the answer for `fib(6)`. A wrong return
value teaches that `fib(0)` is 8. No return value teaches nothing, which is
better.

**SPEC-MEM-060 was validated against a real debugger on a real target on
2026-08-05.** `fib(6)` produced 25 invocations, 25 observed return values, and
**zero wrong values**. `fib(n-1) + fib(n-2)` occupies one source line and
produced **two different return addresses**, which is the assumption this rule
rests on. Three call sites, eleven distinct frame keys, five stack pointers per
recursive site.
[Probe report](../fixtures/toolchain/2026-08-05-linux-x86_64.md),
[RISKS.md](RISKS.md) R-04.

The rule is validated on one toolchain combination. It is re-probed per
architecture ([SPEC-PLAT-040](PLATFORM-SUPPORT.md#spec-plat-040)) and per
toolchain ([ADR-009](decisions/ADR-009-toolchain-pinning.md)).

---

## 10. Invariants that tests enforce

These are checked mechanically. See [TEST-STRATEGY.md](TEST-STRATEGY.md) §4.

| Invariant | Enforced by |
|---|---|
| No identity field matches an address pattern | schema check on every trace fixture |
| Every reference resolves to an identity present in the same materialised step | model invariant test |
| No two distinct keys map to one identity | model invariant test |
| No identity maps to two distinct keys within one run | model invariant test |
| Every variable slot carries exactly one of the four states | schema check |
| A recorded return value's frame identity is present in the trace | model invariant test |
| Identities are equal across two runs of one fixture | determinism test |
