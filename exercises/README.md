# Exercises

An exercise is **data**. The loader reads `exercise.json` and executes nothing
from this directory except the student's own Odin source, through the normal
build path ([SPEC-EX-001](../docs/EXERCISE-SPEC.md#spec-ex-001)). An exercise
cannot change compiler flags, budgets, or the adapter: one that could disable
debug information could disable the tool.

```sh
odin-tutor check exercises/03-slices-share-storage
odin-tutor check exercises/03-slices-share-storage --entry solution.odin
```

## What is in each directory

| File | What it is |
|---|---|
| `exercise.json` | The exercise: objective, assertions, and the file the student edits. |
| `start.odin` | What the student starts from. It does **not** pass. |
| `solution.odin` | A reference solution. Every assertion passes against it. |
| `wrong-*.odin` | A plausible wrong solution the exercise must reject. |

## Why `wrong-*.odin` exists

[SPEC-EX-052](../docs/EXERCISE-SPEC.md): **every exercise must reject at least
one plausible wrong solution.** An exercise that only accepts the right answer
has not been shown to distinguish anything — it might accept everything.

`03-slices-share-storage` is the worked example, and it is the reason this
project exists. Its wrong solution prints `3 2`, exactly like the reference:

```odin
parte := todos[1:]        // a window onto todos
parte := []int{2, 3}      // a second array holding equal values
```

Every test that compares printed output accepts both. Only the picture separates
them, and the difference is real — writing through one is visible through the
other in the first case and not in the second.

## The three verdicts

`pass`, `fail`, and **`undetermined`**. An exercise passes only when every
assertion is `pass` ([SPEC-VAL-002](../docs/VALIDATION-SPEC.md#spec-val-002)).

`undetermined` is never counted as a pass, and it is never reported as the
student's failure. Missing evidence has causes that are not their doing: a
budget was reached, a value was `unreadable`, a return value could not be
attributed. Reporting those as `fail` blames the student for the tool's limit
([SPEC-VAL-001](../docs/VALIDATION-SPEC.md#spec-val-001)).
