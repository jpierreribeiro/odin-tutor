# ci/

Two scripts, and three workflows that are mostly calls to them.

Everything CI does, a person can run. That is deliberate: when CI disagrees with
your machine, the difference has to be findable, and it cannot be found if only
a YAML file knows how the toolchain was installed.

| | |
|---|---|
| [`install-odin.sh`](install-odin.sh) | Install a specific Odin — `pinned`, `latest`, an index where 0 is newest, or a tag. Prints the directory to use as `ODIN_ROOT`. |
| [`debuggable.sh`](debuggable.sh) | Can this machine run a debugger at all? Touches none of this project's code. |

```sh
export ODIN_ROOT=$(./ci/install-odin.sh pinned ~/odin)   # the same one CI uses
./ci/install-odin.sh latest ~/odin-new                   # the newest release
./ci/debuggable.sh                                       # before blaming the tool
```

The pin is [`pinned-odin.txt`](pinned-odin.txt): one release tag, the
combination this project claims to support
([SPEC-PLAT-032](../docs/PLATFORM-SUPPORT.md#spec-plat-032)). A pull request
must not go red because Odin released something yesterday, so pushes use the
pin and only the nightly job goes looking for drift.

## The workflows

| | When | What it answers |
|---|---|---|
| [`check.yml`](../.github/workflows/check.yml) | Every push and pull request | Does a machine nobody configured get the same answer as the author's? |
| [`nightly.yml`](../.github/workflows/nightly.yml) | 04:17 UTC, and on demand | Does today's Odin still emit debug information this tool can read? |
| [`release.yml`](../.github/workflows/release.yml) | A `v*` tag | Does the tarball work for someone who never cloned this? |

Three things in them are deliberate and would be easy to undo by accident.

**`debuggable` runs first and alone.** It is about the machine, not the code. If
a trace fails while it is green, the tool is wrong; if it is red, nothing below
it means anything. Those two answers must never arrive on the same line.

**The nightly matrix is three releases, not one, and none of them is the pin.**
When the newest breaks something the next question is always "and the one before
it?", and answering that from an archived run beats bisecting by hand
([SPEC-PLAT-033](../docs/PLATFORM-SUPPORT.md#spec-plat-033)).

**Probe reports are uploaded, never committed.** A row in the compatibility
table means a person read the report and vouched for it
([SPEC-PLAT-031](../docs/PLATFORM-SUPPORT.md)). A bot committing rows nightly
would turn evidence back into decoration.

## What CI does not do

It does not make macOS work. That needs an LLDB adapter, code-signing
entitlements, and a second architecture — a port of the same order of size as
the original adapter ([PLATFORM-SUPPORT.md §3](../docs/PLATFORM-SUPPORT.md)).
What the macOS job does is smaller and honest: it proves everything that does
not touch a debugger builds and passes there, and that the tool refuses with a
named error rather than crashing. When Phase 7 starts, that job already says how
much of the distance is left.
