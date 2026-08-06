# CURRICULUM

The order the exercises teach in, what each one accompanies, and — just as
important — what will **not** become an exercise, and why.

---

## 1. The spine

The course follows the **official Odin overview**,
<https://odin-lang.org/docs/overview/>, section by section.

That is the same relationship rustlings has to *The Rust Programming Language*
and ziglings has to the Zig docs: the reference explains, the exercises make you
do it. The difference this tool adds is the third step — when you get it wrong,
you see your own memory at the step it went wrong.

The overview was chosen over a book because it is **free, official, and the
thing a person already has open** when they start Odin. A course whose first
instruction is "buy this" has a barrier in front of the second exercise.

> *Going deeper:* **Understanding the Odin Programming Language** (Karl
> Zylinski) covers the same ground at book length, and its chapter order is a
> teaching order that works. This curriculum used to follow it. Where the two
> disagree on ordering, the overview wins, because it is the one every student
> can open.

### The rule that decides which sections become exercises

> An exercise earns its place when the **picture** teaches something the text
> cannot.

Comments, attributes, build tags and calling conventions do not become
exercises: reading about them is enough, and a memory picture of them says
nothing. Pointers do, because "two names, one object" is a sentence in a
reference and a visible fact on the screen.

**The strongest exercises are the ones where the printed output is IDENTICAL for
the right and the wrong answer.** Eight of the twenty-two are built that way on
purpose: `13-sub-slices`, `17-enums`, `18-varargs`, `19-arenas`, `20-errors`,
`21-or-return`, `22-string-copy` and `24-parameters`.
Every test that compares printed text accepts both programs; only the picture
separates them. That is the whole argument for this project in one screen.

---

## 2. Mapping

Twenty-two exercises, against the overview's own section names.

| Overview section | Exercise | What the picture adds |
|---|---|---|
| Hellope, Variable declarations | `01-values` | A variable exists before its line runs, and reads `not yet` rather than stack garbage. |
| Control flow: `for`, `if` | `02-control-flow` | Stepping backward through a loop, one iteration at a time. |
| Fixed arrays | `03-fixed-arrays` | The length is part of the type, not a number stored beside it. |
| Structs | `04-structs` | Fields as named slots, read individually. |
| Pointers | `05-pointers`, `06-aliasing` | **The first place the picture is essential.** Two names showing `-> [7]` is what aliasing *is*. |
| Procedures | `07-frames`, `08-recursion` | The frames column, and a recursion whose depth you can see. |
| Enumerations | `17-enums` | A name is the value. The lookup-table version prints the same word and holds a `1`. |
| Variadic parameters | `18-varargs` | `..int` arrives as a slice whose length is the count the caller wrote. |
| Allocators: `new`, `free` | `10-new-and-free`, `11-lifetime` | An object that exists, then does not; and a pointer that outlives it. |
| Allocators: arenas | `19-arenas` | The mark moves by exactly what you took. Unused, it reads 0. |
| Slices | `12-slices`, `13-sub-slices` | The flagship: a wrong sub-slice prints the right answer. |
| Dynamic arrays | `14-dynamic-arrays` | Capacity against length, two numbers that differ. |
| `string` type, string iteration | `15-strings`, `16-utf8` | A string as `{data, len}`, and bytes against characters. |
| Multiple results | `20-errors` | The failure as a second slot, not as prose. |
| `or_return` | `21-or-return` | The error leaving on its own, instead of a zero that looks like an answer. |
| `string` type conversions | `22-string-copy` | Assigning a string hands over a second view of the same bytes; `strings.clone` makes a second set. Both print the same lengths. |
| Procedures: parameters | `24-parameters` | A parameter is a copy until you pass a pointer. The wrong answer doubles at the call site and prints the same number. |

---

## 3. What will not become an exercise, and why

Each line below was **tried and probed**, not assumed. This section exists so
that "there are only twenty-two" reads as a decision with reasons rather than
as a gap.

| Overview section | Why not |
|---|---|
| Unions, type switch | The model has no rule for a union, so the whole screen reads `unknown` ([R-24](RISKS.md#r-24)). Honest, and it teaches nothing about unions. Tractable — this is the first hole worth closing. |
| Maps | Entries are unreadable through the debugger on this toolchain, so only the count is visible ([R-20](RISKS.md#r-20), [ADR-014](decisions/ADR-014-maps-are-counted-not-walked.md)). |
| Nested structs | **Withheld because the picture is currently WRONG** — two fields of a nested struct are drawn as one shared storage ([R-23](RISKS.md#r-23)). The exercise is written and will land when that is fixed. |
| `defer` | A leak is invisible here by construction: absence from the reachable set is not evidence of anything ([ADR-011](decisions/ADR-011-absence-is-not-evidence.md)), and `defer`'s ordering is an output fact. The picture adds nothing the text does not say. |
| `#soa` | Blocked by the same defect as nested structs ([R-23](RISKS.md#r-23)): `x` and `y` resolve to one identity. |
| Copy versus reference on locals | **Withheld: the picture is WRONG the other way** ([R-25](RISKS.md#r-25)). A pointer to a local is drawn as a second object holding equal values, so `not_alias` reports the opposite of the truth. Written, and waiting. |
| Array and slice CONTENTS — by-reference loops, sorting in place, array arithmetic, `append` moving its storage | Not blocked by a defect but by the vocabulary: [VALIDATION-SPEC.md](VALIDATION-SPEC.md) can count elements and compare lengths, and cannot yet ask what the third element IS. One predicate — an element accessor — turns this row into about six exercises. |
| `distinct` types | Probed: a distinct scalar renders exactly like its base type, so the picture cannot show the difference the type system makes. |
| Implicit context | Filtered out of the picture on purpose. |
| Comments, packages, attributes, build tags, foreign, calling conventions, `when` | Prose, tooling, or compile-time. Nothing to see in memory. |
| Parametric polymorphism, bit sets, `bit_field`, matrices | Marginal. The picture shows the concrete instance, which the text already told you. Candidates if the course ever needs more. |

---

## 4. Order

Exercises are done in the order the tool offers them, which is their id order.
Each one names the overview section it accompanies, so a stuck student has
somewhere to read that is one click away and free.

Ids are stable ([SPEC-EX-011](EXERCISE-SPEC.md#spec-ex-011)): a student's
progress is keyed by them, so an exercise added later takes the next free number
rather than renumbering the ones already finished. That is why the numbering has
gaps and does not run in a straight line — `17-enums` teaches something a
beginner meets early, and it was written late.
