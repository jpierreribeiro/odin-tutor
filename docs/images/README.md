# images

Generated, never edited. Run [`ci/screenshots.sh`](../../ci/screenshots.sh) to
rebuild every file here from the tool as it is right now.

| | |
|---|---|
| `loop` | The exercise loop, failing, with the progress bar and the keys |
| `picture` | The memory at the step the assertion was decided at |
| `contrast` | The same printed output, twice, and only one says `shares with` |
| `done` | A solved exercise, waiting rather than moving on |
| `list` | The whole course |

Each exists as **both** `.svg` and `.png`, from one captured text: GitHub renders
the SVG, and link previews on social sites need a raster.

Two things about them are deliberate.

**They are captured, not typed.** The loop is driven through a pseudo-terminal
and the picture comes from `render`, which shares its one formatter with the
interactive screen ([SPEC-TUI-051](../TUI-SPEC.md#spec-tui-051)). A screenshot
that drifts is worse than none, because it is the first thing a reader believes
— this project shipped a README block for weeks showing a label format the
renderer had stopped producing.

**They are ASCII, not Unicode.** `[2]` and `->` rather than `②` and `→`. That is
the form the tool prints by default and the form
[SPEC-TUI-041](../TUI-SPEC.md#spec-tui-041) guarantees loses nothing — and no
monospace font on a normal Linux box has the circled digits, so the pretty
version renders as empty boxes.
