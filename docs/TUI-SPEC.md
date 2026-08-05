# TUI-SPEC

The terminal user interface.

---

## 1. Principles

1. **The terminal is a grid.** The interface uses columns and lists. It does not
   draw arrows and does not compute a graph layout.
   [ADR-007](decisions/ADR-007-labels-not-arrows.md).
2. **The interface is a consumer.** It reads materialised steps. It computes no
   identity and re-executes nothing.
3. **Everything the trace marks, the screen shows.** A truncation, an `unknown`,
   and a `not-yet-active` each have a visible form.
4. **Colour and Unicode are decoration.** Removing both loses no information.

---

## 2. Layout

```
 STEP 7/26   main.odin:14   sum_grades()   line

 CODE                              FRAMES              OBJECTS
  10 sum_grades :: proc(           main()               ① Student
  11     xs: []int) -> int {         student → ①           name    → ③
  12     total := 0                  grades  → ②           grades  → ②
  13     for n in xs {
▸ 14         total += n            sum_grades()         ② []int  (3)
  15     }                           xs    → ②             [0] 7
  16                                 total = 7            [1] 8
  17     return total                n     = 7            [2] 9
  18 }
                                                        ③ string
                                                           "Ana"

 OUTPUT (so far)
  (none yet)

 ← → step   g jump   Home/End ends   q quit
```

<a id="spec-tui-001"></a>
### SPEC-TUI-001 — Four regions
The interface presents: source with the current line marked; frames; objects;
output so far. A status line names the step, the location, and the event.

<a id="spec-tui-002"></a>
### SPEC-TUI-002 — Objects are numbered, and the number is the reference
An object or view is shown with a label such as `①`. A reference is shown as
`→ ①`. The same label appears at both ends. This is the whole reference
mechanism.

*Rationale:* labels give aliasing, cycles, and shared structure without a layout
algorithm. Two `→ ①` in different frames is aliasing. A field of ① that reads
`→ ①` is a cycle. Both are legible in one screen of text.

<a id="spec-tui-003"></a>
### SPEC-TUI-003 — Label numbering is stable within a step and derived from identity
The label for an identity does not change between steps while the identity
lives. A student who is watching `②` keeps watching the same thing.

*Rationale:* a label that renumbers between steps re-creates, at the
presentation layer, exactly the identity bug the model exists to prevent.

---

## 3. Value states on screen

Each state from [MEMORY-MODEL.md](MEMORY-MODEL.md) §5 has a distinct form. None
is blank.

| State | Default | ASCII mode |
|---|---|---|
| `valid` | `total = 7` | same |
| `not-yet-active` | `n     · not yet` | `n     - not yet` |
| `unreadable` | `q     ✗ unreadable` | `q     ! unreadable` |
| `unknown` | `big   ? unknown (elements budget)` | `big   ? unknown (elements budget)` |

<a id="spec-tui-010"></a>
### SPEC-TUI-010 — No state renders as an empty space
An empty slot is indistinguishable from "there is nothing here", which is a
claim about the program.

<a id="spec-tui-011"></a>
### SPEC-TUI-011 — A frame with no readable variables says which case it is
| `variable_state` | Screen |
|---|---|
| `none` | `(no variables)` |
| `not_yet_active` | `(parameters not readable yet — prologue)` |

*Rationale:* [SPEC-MEM-022](MEMORY-MODEL.md#spec-mem-022). "No variables" at the
entry step of `double(n: int)` asserts the procedure takes no parameters.

---

## 4. Aliasing and shared storage are shown differently

| Relationship | Screen |
|---|---|
| alias | two variables both show `→ ②` |
| shares storage | two views appear as separate entries, and the second carries a note |

```
 ② []int  (3)                 storage S1
    [0] 10  [1] 20  [2] 30

 ④ []int  (2)                 storage S1 — shares with ②
    [0] 10  [1] 20
```

<a id="spec-tui-020"></a>
### SPEC-TUI-020 — Sharing is stated in words
The interface writes `shares with ②`. It does not express sharing only by a
repeated storage label, because a student does not know what a storage label is
until the interface says so.

*Rationale:* [DOMAIN-MODEL.md](DOMAIN-MODEL.md) §3. Showing sharing with the
same mark as aliasing reintroduces the sub-slice bug on screen.

---

## 5. Navigation

<a id="spec-tui-030"></a>
### SPEC-TUI-030 — Required commands

| Key | Action | Requirement |
|---|---|---|
| `→` `n` | next step | [REQ-TUI-003](REQUIREMENTS.md#req-tui-003) |
| `←` `p` | previous step | " |
| `Home` | first step | " |
| `End` | last step | " |
| `g` | prompt for a step index, then jump | " |
| `q` | exit | " |

<a id="spec-tui-031"></a>
### SPEC-TUI-031 — Additional commands
These are investigated and are not required for the first release.

| Key | Action | Why it is useful | Cost |
|---|---|---|---|
| `f` | next step in the current procedure | Skips a nested call the student is not studying | needs a frame-identity filter over the trace |
| `o` | step out: next step where the current invocation has returned | Answers "what did this call produce?" in one key | same filter |
| `/` | jump to the next step where a named variable changes | The most common question a student has | needs a per-identity change index |
| `c` | jump to the crash step | The second most common question | trivial; the trace already marks it |
| `?` | help overlay | Discoverability | trivial |

`c` and `?` are cheap and are recommended for the first release. The rest wait
for evidence that students ask for them.

<a id="spec-tui-032"></a>
### SPEC-TUI-032 — Navigation never blocks on work
Any command completes within the budget in [PERFORMANCE.md](PERFORMANCE.md) §3.
A jump that would exceed it is not permitted to exist: the keyframe interval is
chosen so that it cannot.

---

## 6. Degradation

<a id="spec-tui-040"></a>
### SPEC-TUI-040 — Capability detection
The interface detects: colour support, Unicode support, terminal size. Each has
a command-line override.

<a id="spec-tui-041"></a>
### SPEC-TUI-041 — ASCII mode carries the same information
With `--ascii`, labels become `[1]`, `[2]`, and the state marks use the ASCII
column in §3. No information is lost.

<a id="spec-tui-042"></a>
### SPEC-TUI-042 — Monochrome mode carries the same information
Colour never carries meaning alone. Every distinction that colour makes is also
made by a character or a word.

*Rationale:* accessibility, and the fact that the golden tests read text.

<a id="spec-tui-043"></a>
### SPEC-TUI-043 — Small terminals degrade by dropping regions, in order
When the terminal is too narrow, regions are dropped in this order: source,
then output, then objects. Frames are never dropped. The interface states which
regions it dropped.

<a id="spec-tui-044"></a>
### SPEC-TUI-044 — A minimum size is stated, not assumed
Below 60 columns or 20 rows the interface reports that the terminal is too small
and does not attempt to draw.

---

## 7. Non-interactive rendering

<a id="spec-tui-050"></a>
### SPEC-TUI-050 — `render` produces the same content as the interface
`odin-tutor render --step N` writes the same information as the interactive
screen, as plain text, with no escape sequences and no cursor movement.

Three uses:

1. golden tests ([TEST-STRATEGY.md](TEST-STRATEGY.md) §4);
2. assistive technology, which reads a stream better than a redrawn screen;
3. pasting a step into a bug report or a message to an instructor.

<a id="spec-tui-051"></a>
### SPEC-TUI-051 — The renderer and the interface share one formatter
The two must not drift. The interactive screen is the renderer's output placed
into a layout, not a second implementation.

---

## 8. Implementation decision: no terminal framework

<a id="spec-tui-060"></a>
### SPEC-TUI-060 — Direct ANSI output, no third-party dependency
The interface writes ANSI sequences directly and reads keys through the
platform's terminal mode control.

Reasons:

1. Odin has no mature, widely-used terminal interface library. Adopting an
   immature one is a maintenance risk larger than the code it saves.
2. The layout is columns and lists. It needs no widget system, no focus model,
   and no event loop beyond "read a key, redraw".
3. A dependency here would have to be evaluated against
   [AGENT-GUIDE.md](AGENT-GUIDE.md) Rule 10 for every platform.

The ANSI subset used is documented in one place in the code and is small:
alternate screen, cursor position, clear line, colour, and cursor visibility.

*Decision record:* [ADR-010](decisions/ADR-010-no-tui-framework.md).

<a id="spec-tui-061"></a>
### SPEC-TUI-061 — Terminal state is restored
The interface restores the terminal on exit, including after an error and after
a signal. A test asserts this.

*Rationale:* a tool that leaves a terminal unusable is remembered for that and
nothing else.
