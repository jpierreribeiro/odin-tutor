# CURRICULUM

The order the exercises teach in, and where each one comes from.

---

## 1. The spine

The curriculum follows *Understanding the Odin Programming Language* by Karl
Zylinski. Its chapter order is already a teaching order that works, and
reproducing that order costs nothing and inherits its judgement.

This is the same relationship rustlings has to *The Rust Programming Language*:
the book explains, the exercises make you do it. The difference is what this
tool adds — the book can show you a diagram of a slice; the tool shows you
**your** slice, at the step your code was wrong.

### The rule that decides which chapters become exercises

> An exercise earns its place when the **picture** teaches something the text
> cannot.

A chapter about naming conventions does not become an exercise. A chapter about
pointers does, because "two names, one object" is a sentence in a book and a
visible fact on the screen.

---

## 2. Mapping

| Book chapter | Exercises | Why the picture helps |
|---|---|---|
| 3 Variables and constants | `01-values` | The four value states appear immediately: a variable exists before its line runs, and shows `not created yet` rather than stack garbage. |
| 4 Some additional basics | `02-control-flow`, `03-fixed-arrays` | Stepping backward through a loop is the whole lesson. |
| 5 Making new types | `04-structs` | Fields as named slots, not as a printed line. |
| 6 Pointers | `05-pointers`, `06-aliasing` | **The first chapter where the picture is essential.** Two names showing `-> #7` is what aliasing *is*. |
| 7 Procedures and scopes | `07-frames`, `08-recursion` | The frames column, and a recursion whose depth you can see. `fib` shows five frames with five different `n`. |
| 8 Fixed-memory containers | `09-fixed-containers` | Capacity against length, visible as two numbers that differ. |
| 9 Manual memory management | `10-new-and-free`, `11-lifetime` | An object that exists, then does not. **See §4 — this is where the tool's limits are honest.** |
| 10 More container types | `12-slices`, `13-sub-slices`, `14-dynamic-arrays` | The sub-slice exercise is the flagship: a wrong solution prints the right answer and the picture shows why it is wrong. |
| 11 Strings | `15-strings`, `16-utf8` | A string as `{data, len}`, and the byte-against-character distinction made visible. |
| 12 Implicit context | — | No exercise. The context is filtered out of the picture on purpose. |
| 13 Making memory easier | `17-arenas` | Allocations grouped by lifetime, dying together. |
| 14 Parametric polymorphism | `18-generics` | Marginal. The picture adds little. |
| 15 Bit-related types | `19-bit-sets` | Marginal. |
| 16 Error handling | `20-errors` | The multiple-return convention as slots, not as prose. |
| 20 Data-oriented design | `21-soa` | Structure of arrays against array of structures, side by side. |
| 22 Debuggers | — | The tool *is* this chapter. |
| 23 Features to avoid | — | Prose, not practice. |

Chapters 1, 2, 17, 18, 19, 21, 24–30 produce no exercises. They are setup,
tooling, or reference.

---

## 3. Order

Exercises are numbered in the order above and are meant to be done in it. Each
one names the chapter it follows, so a stuck student has somewhere to read.

### SPEC-CURR-001 — An exercise names its chapter
`exercise.json` carries a `reading` field: the chapter and section. It is a
pointer, not a copy. This project does not reproduce the book's text.

### SPEC-CURR-002 — Every exercise rejects a plausible wrong solution
[SPEC-EX-052](EXERCISE-SPEC.md#spec-ex-052). An exercise whose assertions pass
for a wrong answer teaches the wrong thing with the tool's authority behind it.

The worked example is `13-sub-slices`, where the wrong solution produces the
**right printed output** and only the picture shows the mistake. If an exercise
cannot be given such a case, it is a reading, not an exercise.

---

## 4. Where the curriculum must not overreach

Two chapters describe things this tool **cannot show**, and the exercises for
them are written around that rather than pretending.

### Chapter 9, use after free
The tool cannot detect it. Measured 2026-08-05: reading through a pointer after
`free` returned `8313165202016105638` with no error, because the region stays
mapped. [R-21](RISKS.md#r-21).

`10-new-and-free` therefore teaches allocation and release as **events in the
program**, and its assertions are about what the code did, not about the tool
catching a mistake. The exercise text says so. A student who believes the tool
would have caught a use-after-free has been taught something false about their
own safety.

### Chapter 10, maps
Map entries are not readable through the debugger on this toolchain: the type
exposes `data`, `len`, and `allocator`, and nothing else.
[R-20](RISKS.md#r-20), [SPEC-MEM-053](MEMORY-MODEL.md#spec-mem-053).

There is no map exercise in the list above, and that is deliberate. An exercise
about a container the picture cannot open is a worse experience than no
exercise. If [ADR-014](decisions/ADR-014-maps-are-counted-not-walked.md) is ever revisited in favour of decoding the layout, `12b-maps` joins
the list; until then it does not exist.

---

## 5. Attribution

The book is *Understanding the Odin Programming Language*, by Karl Zylinski.
This project uses its **chapter order** as a curriculum spine and cites it as
reading. It reproduces none of its text, and it is not a substitute for it.
