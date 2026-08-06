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
the right and the wrong answer.** Twenty-two of the thirty-three are, and the
acceptance script counts them rather than a list here being kept by hand — which
it was, and which had drifted to a stale ten with two exercises in it that did
not qualify.
Every test that compares printed text accepts both programs; only the picture
separates them. That is the whole argument for this project in one screen.

---

## 2. Mapping

Thirty-three exercises, against the overview's own section names.

| Overview section | Exercise | What the picture adds |
|---|---|---|
| Hellope, Variable declarations | `01-values` | A variable exists before its line runs, and reads `not yet` rather than stack garbage. |
| Control flow: `for`, `if` | `02-control-flow` | Stepping backward through a loop, one iteration at a time. |
| Fixed arrays | `03-fixed-arrays` | The length is part of the type, not a number stored beside it. |
| Array programming | `29-array-math` | `a + b` applies to every element, so the loop that could stop one short is not written at all. |
| Swizzle operations | `30-swizzle` | `.zyx` names an order and builds a new array in it, leaving the original alone. |
| Structs | `04-structs`, `09-nested-structs` | Fields as named slots, read individually — and a struct inside a struct, read all the way down. |
| Pointers | `05-pointers`, `06-aliasing` | **The first place the picture is essential.** Two names showing `-> [7]` is what aliasing *is*. |
| Procedures | `07-frames`, `08-recursion` | The frames column, and a recursion whose depth you can see. |
| Enumerations | `17-enums` | A name is the value. The lookup-table version prints the same word and holds a `1`. |
| Variadic parameters | `18-varargs` | `..int` arrives as a slice whose length is the count the caller wrote. |
| Allocators: `new`, `free` | `10-new-and-free`, `11-lifetime` | An object that exists, then does not; and a pointer that outlives it. |
| `defer` statement | `31-defer` | The leak prints exactly what the tidy program prints, and the object vanishes from the picture either way. Only the free the program REPORTED separates them ([ADR-016](decisions/ADR-016-a-free-is-evidence.md)). |
| Allocators: arenas | `19-arenas` | The mark moves by exactly what you took. Unused, it reads 0. |
| Slices | `12-slices`, `13-sub-slices` | The flagship: a wrong sub-slice prints the right answer. |
| Dynamic arrays | `14-dynamic-arrays` | Capacity against length, two numbers that differ. |
| `string` type, string iteration | `15-strings`, `16-utf8` | A string as `{data, len}`, and bytes against characters. |
| Multiple results | `20-errors` | The failure as a second slot, not as prose. |
| SOA data types | `28-soa` | The only edit is `#soa`, and the code reads the same. One array per field instead of one struct per element — an arrangement nothing in the source shows. |
| Distinct types | `32-distinct` | `id: main::User_Id = 7` beside `plain = 7`. Same bytes, same printed value; the screen names the type and nothing else would. |
| Maps | `33-maps` | The count is measured and the entries are not. Writing a key twice does not add a second one — a lesson the count alone can teach. |
| Unions, type switch | `27-unions` | One member, named by the type it holds. The struct-with-a-flag version prints the same and can be in states a union cannot. |
| `or_return` | `21-or-return` | The error leaving on its own, instead of a zero that looks like an answer. |
| `string` type conversions | `22-string-copy` | Assigning a string hands over a second view of the same bytes; `strings.clone` makes a second set. Both print the same lengths. |
| Structs: assignment | `23-struct-copy` | Two objects, or one object with two names. The tool could not draw this correctly until [R-25](RISKS.md#r-25) was fixed, which is why the exercise arrived after the defect. |
| Procedures: parameters | `24-parameters` | A parameter is a copy until you pass a pointer. The wrong answer doubles at the call site and prints the same number. |
| `for` by reference | `25-in-place` | `for &n` writes into the slice; the by-value version computes on the way to the screen and changes nothing. |
| Sort slices | `26-sorting` | Sorting in place reorders the buffer every other name shares; sorting a clone leaves the original as it was. |

---

## 3. What will not become an exercise, and why

Each line below was **tried and probed**, not assumed. This section exists so
that "there are only thirty-three" reads as a decision with reasons rather than
as a gap.

| Overview section | Why not |
|---|---|
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
