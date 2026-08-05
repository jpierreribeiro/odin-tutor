# DOMAIN-MODEL

The entities the system reasons about, and how they relate.

This document names things. [MEMORY-MODEL.md](MEMORY-MODEL.md) gives the rules
that govern the memory entities. [TRACE-SPEC.md](TRACE-SPEC.md) gives their wire
form.

---

## 1. Entity map

```
  Exercise ────────< Assertion
      │
      │ has one
      v
  Program ──────────> Build ──────────> Executable
                                            │
                                            │ produces one
                                            v
                                          Run
                                            │
                                            │ produces one
                                            v
                                          Trace
                                            │
                                            │ has many, ordered
                                            v
                                          Step
                                         ╱  │  ╲
                                        ╱   │   ╲
                                   Frame  Object  View
                                      │      │     │
                                   Variable  └──┬──┘
                                                │
                                             Storage
```

---

## 2. Entities

### Exercise
A directory. Contains metadata, one program, and assertions. See
[EXERCISE-SPEC.md](EXERCISE-SPEC.md).

An exercise is data. It contains no executable configuration.

### Program
One or more Odin source files. Version 1 supports exactly one.

### Build
One invocation of the Odin compiler with debug information enabled. Produces an
executable or a compile failure with diagnostics.

A build is not cached across toolchain versions. The recorded toolchain is part
of the build's identity.

### Executable
A file with debug information. Input to a Run.

### Run
One execution of one executable under one adapter. Produces:

- a stream of observation records;
- the target program's standard output and standard error;
- an outcome (exit code or signal);
- a run report.

A Run happens **once** per Trace ([REQ-EXEC-003](REQUIREMENTS.md#req-exec-003)).

### Trace
The complete record of a Run, in semantic form. Owns the ordered Steps and the
budget records. See [TRACE-SPEC.md](TRACE-SPEC.md).

A Trace is immutable once written.

### Step
One recorded point of execution. Carries an event kind, a source location, the
frames, and the reachable entities.

A Step in storage is a keyframe or a delta. A **materialised step** is the
complete state, which the core reconstructs. Consumers work with materialised
steps only.

### Frame
One invocation of one procedure, at one Step. Carries a frame identity, a
procedure name, a location, the variables, and a variable-state summary.

A Frame belongs to exactly one Step. The **same invocation** appears in many
Steps and keeps the same frame identity across them
([SPEC-MEM-060](MEMORY-MODEL.md#spec-mem-060)).

### Variable
A name in a Frame, with a state and, when the state is `valid`, a value. A value
is a scalar, a pointer value, or a reference.

A Variable is not an entity with identity. It is a slot. The thing it may refer
to has identity.

### Storage
A region of target memory with a lifetime and an epoch. See
[MEMORY-MODEL.md](MEMORY-MODEL.md) §2.

### Object
A typed value occupying a Storage. Has fields. Fields may refer to other Objects
or Views, which is how cycles appear.

### View
A window on a Storage: offset and length. An Odin slice, string, or dynamic
array. Two Views may share one Storage.

### Assertion
A statement about a Trace that evaluates to `pass`, `fail`, or `undetermined`.
See [VALIDATION-SPEC.md](VALIDATION-SPEC.md).

---

## 3. Relationships that carry meaning

| Relationship | Definition | Where it is decided |
|---|---|---|
| **refers to** | A Variable or a field resolves to an Object or a View identity. | Core, on resolution |
| **alias** | Two Variables refer to the same identity. | Derived by a consumer |
| **shares storage** | Two Views have the same Storage identity, with different offset or length. | Core, recorded |
| **cycle** | A path of references returns to its start. | Derived by a consumer |
| **same invocation** | Two Frames in different Steps carry the same frame identity. | Core, from the frame key |

### Why *alias* and *shares storage* are different

`alias` means "these two names are the same thing". `shares storage` means
"these two things live in the same memory". For:

```odin
a := []int{10, 20, 30}
b := a[:2]
c := a
```

`a` and `c` alias. `a` and `b` share storage and do **not** alias. Collapsing
the two is the sub-slice bug ([MEMORY-MODEL.md](MEMORY-MODEL.md) §1, item 2).

A consumer that shows both relationships with the same visual mark reintroduces
the bug at the presentation layer. [TUI-SPEC.md](TUI-SPEC.md) §4 states how they
differ on screen.

---

## 4. Lifecycles

### Storage
```
minted ──> live ──> absent ──> (address reappears) ──> new epoch, new identity
```
Version 1 detects `absent` by reachability, not by observing the allocator. The
gap is [SPEC-MEM-042](MEMORY-MODEL.md#spec-mem-042).

### Frame
```
entered (call) ──> present in N steps ──> returned ──> gone
```
The `return` event is recorded on the last Step where the Frame is still
present, so the student sees the Frame and the value it produced at the same
time.

### Trace
```
assembling ──> written ──> immutable
```
A Trace that reached a budget is still written and still immutable. Truncation
is a property of a complete Trace, not an incomplete one.

---

## 5. What has identity, and what does not

| Has identity | Does not |
|---|---|
| Storage | Variable (a slot) |
| Object | Value (a reading) |
| View | Step (has an index, which is a position, not an identity) |
| Frame (an invocation) | Assertion (has an index within its exercise) |

### Why a Step has an index and not an identity
Steps are a sequence. Nothing refers to a Step from another Step. An index is
enough and is the natural key for navigation.

### Why a Variable has no identity
A variable is a name in a frame. Two frames may both have `n`. They are not the
same variable, and nothing needs to state that they are. What needs identity is
the thing a variable refers to.
