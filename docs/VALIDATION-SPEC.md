# VALIDATION-SPEC

The assertion language, and how a verdict is reached.

This document is a **specification, not an implementation plan**. Nothing here
is built before [ROADMAP.md](ROADMAP.md) Phase 5.

---

## 1. Principles

1. **Assertions read the trace, not the source.** A student who reaches the
   correct picture by a different route passes.
   [REQ-EX-002](REQUIREMENTS.md#req-ex-002).
2. **Three verdicts, and `undetermined` is not a pass.**
   [REQ-EX-003](REQUIREMENTS.md#req-ex-003).
3. **An assertion is total.** Every assertion returns a verdict. None throws.
4. **A failure explains itself.** The report names the assertion, the step, and
   what was observed. [REQ-EX-004](REQUIREMENTS.md#req-ex-004).

---

## 2. Verdicts

| Verdict | Meaning |
|---|---|
| `pass` | The trace contains the evidence, and it satisfies the assertion. |
| `fail` | The trace contains the evidence, and it contradicts the assertion. |
| `undetermined` | The trace does not contain the evidence. |

<a id="spec-val-001"></a>
### SPEC-VAL-001 — `undetermined` is produced, never `fail`, when evidence is missing
Missing evidence has causes that are not the student's fault: a budget was
reached, a value was `unreadable`, a return value could not be attributed. A
`fail` in those cases would blame the student for the tool's limit.

<a id="spec-val-002"></a>
### SPEC-VAL-002 — An exercise passes only when every assertion is `pass`
`undetermined` blocks the pass and is reported with its cause, so the student
knows to shorten the program rather than to change the logic.

<a id="spec-val-003"></a>
### SPEC-VAL-003 — The report distinguishes the three
The report never renders `undetermined` as a failure of the solution.

---

## 3. Step selectors

An assertion states where it is evaluated.

| Selector | Meaning |
|---|---|
| `final` | The last step of the trace. |
| `any` | True when the assertion holds at **at least one** step. |
| `all` | True when the assertion holds at **every** step where its subjects exist. |
| `first_where(<predicate>)` | The first step where the predicate holds. |
| `at_line(N)` | The first step whose location is line `N`. |
| `on_return_of("proc")` | The step carrying the `return` event for an invocation of `proc`. |

<a id="spec-val-010"></a>
### SPEC-VAL-010 — `any` and `all` interact with truncation
Under a truncated trace:

- `any` that has not yet been satisfied is `undetermined`, not `fail`;
- `all` that has held so far is `undetermined`, not `pass`.

*Rationale:* truncation removes evidence. Neither direction may be assumed.

<a id="spec-val-011"></a>
### SPEC-VAL-011 — A selector that matches no step is `undetermined`
`at_line(99)` in a trace that never reached line 99 is `undetermined`.

---

## 4. Predicates

Subjects are named by a path. A path names a variable in a frame, or reaches
through fields:

```
"total"                    a variable in the innermost student frame
"main:student"             a variable in a named frame
"main:student.grades"      a field of the object it refers to
"main:head.next.next"      two hops
```

<a id="spec-val-020"></a>
### SPEC-VAL-020 — Path resolution
A path resolves to an identity, a scalar, or nothing. A path that resolves to
nothing makes its assertion `undetermined`, never `fail`.

*Rationale:* a name that does not exist may mean the student named it
differently. That is not evidence of a wrong picture.

<a id="spec-val-026"></a>
### SPEC-VAL-026 — An element is named by its index
A path may index a collection: `marks[2]` reaches the third element, and
`casa.cantos[1].x` reaches a field of an element. An index is a hop like a field
name, because that is exactly what it already was — the adapter names elements
`[0]`, `[1]`, `[2]` and the walk matched them by name all along.

| Path | Reaches |
|---|---|
| `marks` | the collection |
| `marks[2]` | its third element |
| `casa.cantos[1].x` | a field, of an element, of a field |

An unbalanced bracket resolves to nothing, so the assertion is `undetermined`
and names the expression. It is an authoring mistake, and guessing an index from
a malformed path would hide it.

*Rationale:* without this, the vocabulary could count elements and compare
lengths and could not ask **what the third element is**. That made a whole class
of exercise unwritable — a loop that doubles in place, a sort that sorts the
buffer it was given, an append that moved its storage — because in every one of
them the right and the wrong answer print the same thing and differ only in what
the collection now holds.

Only collections whose elements the adapter records have members: slices,
dynamic arrays and strings do, and a fixed array of scalars is currently
recorded as one compact text instead ([R-26](RISKS.md#r-26)).

### Identity and relationship

| Predicate | True when |
|---|---|
| `alias(a, b)` | Both paths resolve to the **same** identity. |
| `not_alias(a, b)` | Both resolve, to **different** identities. |
| `shares_storage(a, b)` | Both resolve to views whose storage identity is equal. |
| `not_shares_storage(a, b)` | Both resolve to views whose storage identities differ, or either has no storage. |
| `distinct(a, b)` | `not_alias(a, b)` **and** `not_shares_storage(a, b)`. |
| `is_nil(a)` | The path resolves to a pointer value that is null. |
| `is_reference(a)` | The path resolves to a **pointer**, rather than to the object itself. |

<a id="spec-val-024"></a>
### SPEC-VAL-024 — A reference and the thing it refers to are different subjects
`p := &thing` and `thing` reach the same object, and they are not the same
variable. Without this predicate an exercise cannot say "this must be allocated"
or "pass a pointer, not a copy": a local struct and a pointer to one both resolve
to an object, and every assertion available reads the same on both.

*Rationale:* found while writing `10-new-and-free`. Its wrong solution used a
local where the exercise asked for an allocation, and no predicate in this
document could tell them apart, so the exercise accepted it. An exercise that
accepts a wrong answer has not been shown to distinguish anything
([SPEC-EX-052](EXERCISE-SPEC.md)).

This is what [SPEC-EX-040](EXERCISE-SPEC.md#spec-ex-040) means by a tag that
cannot be asserted on being a gap tracked here. `pointer` was such a tag.

<a id="spec-val-021"></a>
### SPEC-VAL-021 — `alias` and `shares_storage` are separate predicates
There is no single predicate that means "related". The two relationships are
different and an exercise must say which it means.
[DOMAIN-MODEL.md](DOMAIN-MODEL.md) §3.

### Structure

| Predicate | True when |
|---|---|
| `length_of(a)` | Yields the length of a view, for comparison. |
| `element_count(a)` | Yields the number of elements the trace recorded. |
| `field_count(a)` | Yields the number of fields recorded on an object. |
| `chain_length(a, "field", n)` | Following `field` from `a` visits exactly `n` distinct identities before reaching nil. |
| `cycle(a, "field")` | Following `field` from `a` returns to an already-visited identity. |
| `object_count(n)` | The step's object count equals `n`. |
| `type_of(a) == "T"` | The recorded type name equals `T`. |

<a id="spec-val-022"></a>
### SPEC-VAL-022 — `chain_length` counts identities, not hops
A cyclic chain does not loop forever: it stops when it revisits an identity, and
then `chain_length` is `fail` while `cycle` is `pass`.

<a id="spec-val-023"></a>
### SPEC-VAL-023 — A predicate over a truncated collection is `undetermined`
`element_count` on a view whose `truncated` flag is set is `undetermined`. The
recorded count is a floor, not the count.

### Values and behaviour

| Predicate | True when |
|---|---|
| `value_of(a) == "42"` | The recorded scalar text equals the literal. |
| `state_of(a) == "valid"` | The variable's state equals one of the four states. |
| `returns("proc", "42")` | An invocation of `proc` recorded that return value. |
| `output_equals(s)` | The program's whole standard output equals `s`. |
| `output_contains(s)` | It contains `s`. |
| `exits_with(n)` | The outcome is a normal exit with code `n`. |
| `terminated_by("SIGSEGV")` | The outcome is termination by that signal. |

<a id="spec-val-024"></a>
### SPEC-VAL-024 — `returns` is `undetermined` when attribution failed
When the trace records `returned: {state: "unknown"}` for every invocation of
`proc`, `returns` is `undetermined`, never `fail`.
[SPEC-MEM-061](MEMORY-MODEL.md#spec-mem-061).

### Negative and quality predicates

| Predicate | True when |
|---|---|
| `no_unknown_in(frame)` | Every variable in the named frame has state `valid`. |
| `no_budget_reached()` | The trace reached no budget. |

<a id="spec-val-025"></a>
### SPEC-VAL-025 — Quality predicates are for exercise authors
`no_budget_reached` exists so that an exercise's own test can assert its
reference solution stays inside the budgets
([SPEC-EX-051](EXERCISE-SPEC.md#spec-ex-051)). It is not for student-facing
assertions.

---

## 5. Composition

```
expr := predicate
      | expr "and" expr
      | expr "or" expr
      | "not" expr
      | "(" expr ")"
      | value_expr comparison value_expr
```

<a id="spec-val-030"></a>
### SPEC-VAL-030 — Three-valued logic
| `and` | pass | fail | undet |
|---|---|---|---|
| **pass** | pass | fail | undet |
| **fail** | fail | fail | fail |
| **undet** | undet | fail | undet |

| `or` | pass | fail | undet |
|---|---|---|---|
| **pass** | pass | pass | pass |
| **fail** | pass | fail | undet |
| **undet** | pass | undet | undet |

`not` maps pass↔fail and leaves undetermined unchanged.

*Rationale:* this is Kleene's strong three-valued logic. It has the property the
project needs: an unknown never becomes a known by composition.

<a id="spec-val-031"></a>
### SPEC-VAL-031 — The language has no loops and no user-defined names
It is a predicate language, not a scripting language. It terminates by
construction. An exercise cannot execute arbitrary logic during validation.

---

## 6. Failure report

```
Exercise 03-slices-share-storage — not yet

  A1  shares_storage("todos", "parte")           FAIL   at step 6 (main.odin:8)

      todos → ② []int (3)   storage S1
      parte → ④ []int (2)   storage S2

      The two slices are in different storage. `parte` is a new array,
      not a window on `todos`.

      [t] show this step   [h] hint   [q] quit
```

<a id="spec-val-040"></a>
### SPEC-VAL-040 — Three required elements
The report names the assertion, the step, and the observed state. It does not
say only "failed".

<a id="spec-val-041"></a>
### SPEC-VAL-041 — The explanation is authored, not generated
The sentence under the observed state comes from the exercise, keyed by
assertion id. A generated explanation would restate the predicate, which the
student already read.

<a id="spec-val-042"></a>
### SPEC-VAL-042 — Only the first failing assertion is shown
Showing all of them at once, on a first attempt, is discouraging and usually
redundant, because one mistake fails several assertions.

---

## 7. Gaps

Concepts from [EXERCISE-SPEC.md](EXERCISE-SPEC.md) §5 that this language cannot
yet assert on. Each is a tracked gap, not an omission.

| Concept | Why not | Depends on |
|---|---|---|
| `free`, `ownership`, `dangling` | The trace cannot observe deallocation in version 1 | [SPEC-MEM-042](MEMORY-MODEL.md#spec-mem-042); Roadmap Phase 6 |
| `mutation` as an event | The trace records state per step, not a change event; a consumer can diff, but there is no predicate | A `changed_at(path)` predicate over adjacent steps; deferred |
| `copy` versus `move` | Odin's semantics here are not represented in the model | Analysis needed before a predicate is designed |

<a id="spec-val-050"></a>
### SPEC-VAL-050 — A gap is recorded, not worked around
An exercise must not approximate a missing predicate with `output_equals`.
That reintroduces the failure the project exists to prevent: a check that passes
on the right output and the wrong picture.
