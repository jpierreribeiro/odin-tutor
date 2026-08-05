# EXERCISE-SPEC

The exercise format.

---

## 1. What an exercise is

A directory. It contains data only. It contains no script and no build
configuration.

```
exercises/
  03-slices-share-storage/
    exercise.json      metadata and assertions
    start.odin         what the student receives
    solution.odin      a reference solution, used by tests
    hints.md           progressive hints
    README.md          the explanation the student reads
```

<a id="spec-ex-001"></a>
### SPEC-EX-001 — An exercise is data
The loader reads `exercise.json`. It executes nothing from the exercise
directory except the student's Odin source, through the normal build path.

*Rationale:* an exercise is content. Content that can execute is a different
kind of artefact with a different review standard.

<a id="spec-ex-002"></a>
### SPEC-EX-002 — The build configuration belongs to the tool
An exercise cannot change compiler flags, budgets, or the adapter.
[REQ-EXEC-001](REQUIREMENTS.md#req-exec-001) requires debug information; an
exercise that could disable it could disable the tool.

---

## 2. `exercise.json`

```jsonc
{
  "id": "03-slices-share-storage",
  "title": "Two windows on one array",
  "objective": "Show that a sub-slice shares memory with the slice it came from.",
  "concepts": ["slice", "shared-storage", "aliasing"],
  "difficulty": 2,
  "requires": ["01-variables", "02-slices"],

  "entry": "start.odin",
  "stdin": "",

  "assertions": [
    { "id": "A1", "at": "final",
      "expr": "shares_storage(\"todos\", \"parte\")" },
    { "id": "A2", "at": "final",
      "expr": "not_alias(\"todos\", \"parte\")" },
    { "id": "A3", "at": "final",
      "expr": "length_of(\"parte\") == 2" },
    { "id": "A4", "at": "any",
      "expr": "output_equals(\"3 2\\n\")" }
  ],

  "hints": ["hints.md"],
  "expected_wall_ms": 3000
}
```

<a id="spec-ex-010"></a>
### SPEC-EX-010 — Fields
| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Stable. Used for progress. Never reused. |
| `title` | yes | One short line. |
| `objective` | yes | One sentence, stated in terms of the picture where possible. |
| `concepts` | yes | Tags from the controlled list in §5. |
| `difficulty` | yes | 1 to 5. Advisory only. |
| `requires` | no | Exercise ids the student should finish first. Advisory. |
| `entry` | yes | The file the student edits. |
| `stdin` | no | Fixed input. Must be deterministic. |
| `assertions` | yes | At least one. See [VALIDATION-SPEC.md](VALIDATION-SPEC.md). |
| `hints` | no | Ordered hint files. |
| `expected_wall_ms` | no | Advisory budget for the exercise author. |

<a id="spec-ex-011"></a>
### SPEC-EX-011 — Ordering is data, not directory order
The tool orders exercises by `id`, and uses `requires` only to warn. It does not
infer order from the file system.

*Rationale:* directory order changes when a file is renamed. An id does not.

---

## 3. The exercise loop

```
watch start.odin
      │  file changed
      v
   build ──── failure ──> show compiler diagnostics, wait
      │ success
      v
   trace ──── adapter failure ──> show the error class, wait
      │ success
      v
   validate
      │
      ├── every assertion passes ──> "done", offer the next exercise
      │
      └── otherwise ──> show the first failing assertion, offer:
                          [t] open the step player at the relevant step
                          [h] next hint
```

<a id="spec-ex-020"></a>
### SPEC-EX-020 — A failure opens the picture
When an assertion fails, the tool offers to open the step player positioned at
the step the assertion was evaluated at.

*Rationale:* this is the feature that distinguishes the project from Rustlings.
A compile-error tutorial can only say "wrong". This one can show why.

<a id="spec-ex-021"></a>
### SPEC-EX-021 — Hints are ordered and are requested
Hints are shown one at a time and only on request. The tool never shows a hint
automatically.

---

## 4. Progress

<a id="spec-ex-030"></a>
### SPEC-EX-030 — Progress is a local file
Progress is stored in the user's work directory, keyed by exercise id. It
records: attempted, passed, and the timestamp of the pass.

<a id="spec-ex-031"></a>
### SPEC-EX-031 — Progress is advisory
The student may run any exercise at any time. `requires` produces a note, not a
lock.

---

## 5. Concept tags

A controlled list. Adding a tag requires updating this list. This is what makes
a curriculum audit possible.

```
variable  constant  scalar  string
array  slice  dynamic-array  shared-storage
struct  field  nested-struct
pointer  reference  nil  dangling
allocation  free  ownership
procedure  parameter  return  frame  recursion
loop  conditional  iteration
mutation  aliasing  copy
conversion  data-structure  cycle
```

<a id="spec-ex-040"></a>
### SPEC-EX-040 — The curriculum is not designed here
This document defines the format. The set of exercises is content, produced
later, and reviewed for pedagogy rather than for architecture.

What this format must support is that each tag above can be the *subject* of an
exercise whose success condition is visible in the picture. A tag that cannot be
asserted on is a gap in [VALIDATION-SPEC.md](VALIDATION-SPEC.md), and is tracked
there.

---

## 6. Authoring rules

<a id="spec-ex-050"></a>
### SPEC-EX-050 — An exercise must be deterministic
No clock, no randomness without a fixed seed, no environment dependence, no
file or network access. The loader warns when the source contains an obvious
source of nondeterminism.

*Rationale:* an assertion on a nondeterministic trace fails intermittently, and
an intermittent failure in a teaching tool teaches the student that the tool is
broken.

<a id="spec-ex-051"></a>
### SPEC-EX-051 — An exercise must be small
An exercise that reaches a budget cannot be validated reliably, because an
assertion beyond the truncation point yields `undetermined`
([REQ-EX-003](REQUIREMENTS.md#req-ex-003)). The authoring test asserts that the
reference solution reaches no budget.

<a id="spec-ex-052"></a>
### SPEC-EX-052 — Every exercise has a negative test
An exercise ships with at least one *plausible wrong* solution, and a test that
asserts the validator rejects it.

*Rationale:* an assertion set that accepts the reference solution proves
nothing. The risk is an assertion set that accepts everything. The wrong
solution is what proves the assertions bite. This mirrors
[TEST-STRATEGY.md](TEST-STRATEGY.md) §4.

---

## 7. Reference exercise, worked

`start.odin`:

```odin
package main
import "core:fmt"

main :: proc() {
    todos := []int{10, 20, 30}
    // TODO: make `parte` the first two elements of `todos`,
    //       without copying.
    parte: []int
    fmt.println(len(todos), len(parte))
}
```

Assertions require that `parte` shares storage with `todos`, is not an alias of
it, and has length 2.

A plausible wrong solution, which the negative test must reject:

```odin
parte := []int{10, 20}      // right output, wrong picture
```

This produces `3 2` on standard output, so an output-only check passes. The
picture is wrong: two storages, no sharing. `A1` fails and the student is shown
the two separate objects.

This example is why the project exists.
