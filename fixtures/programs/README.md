# Fixture programs

The minimum set from [TEST-STRATEGY.md](../../docs/TEST-STRATEGY.md) §5. Each is
one small Odin program that isolates one thing the tool must get right.

These are **student code**, not tool code. They are compiled and traced, never
imported. Each is built as a single file:

```sh
odin build fixtures/programs/<name>.odin -file -debug -out:<name>
```

Every identifier is English, matching the rest of the repository. The programs
under [`../toolchain/`](../toolchain/) keep their original Portuguese names on
purpose: the 2026-08-05 probe report quotes them literally — `Aluno` exposed
`['nome', 'notas', 'idade']` — and renaming them would break the evidence.

## The rule these exist for

**Unknown is better than false** ([ADR-008](../../docs/decisions/ADR-008-unknown-over-false.md)).
Most of these fixtures are not testing that the tool works. They are testing
that it does not produce a picture that is wrong and believable. The comment at
the top of each one names the lie it prevents.

## Values and structure

| Fixture | What it pins |
|---|---|
| `scalars` | The walking skeleton. One assignment per line, so the step count is checkable against the source. |
| `string` | A string is read through `{data, len}`, not as a null-terminated run of bytes. |
| `fixed-array` | A fixed array carries its length in its type. It is not a slice and has no storage to share. |
| `nested-struct` | A struct inside a struct is one storage. The inner fields are reached by path, not by following anything. |
| `struct-in-slice` | Each element is an object with its own identity, and all of them share the slice's one storage. |

## Slices

| Fixture | The lie it prevents |
|---|---|
| `slice-of-int` | — the reference shape. |
| `two-empty-slices` | Two empty slices become one object. Both have a nil pointer and length 0. |
| `sub-slice` | A sub-slice drawn with its parent's length, or given a storage of its own so the sharing disappears. |
| `dynamic-array-append` | A growth that moves the storage looks like the variable being replaced. |
| `two-equal-lists` | Equal contents become one object. |

## Pointers and graphs

| Fixture | The lie it prevents |
|---|---|
| `pointer-to-struct` | — the reference shape for following a pointer. |
| `linked-list-4` | — the reference shape for the object graph. |
| `cycle` | Infinite expansion, or a cycle drawn as an endless chain of distinct objects. |
| `rawptr` | An invented target for an unshaped pointer. |
| `invalid-pointer` | A fabricated object behind an unmapped address. |
| `dangling-pointer` | Claiming the tool detects use after free. **It cannot.** |
| `free-then-allocate` | A new object inheriting a freed object's identity. **Known incorrect in version 1.** |
| `truncated-then-restored` | A display budget changing an identity. |

## Frames

| Fixture | The lie it prevents |
|---|---|
| `simple-call` | Withholding every return value and passing the fibonacci test vacuously. |
| `two-calls-one-line` | One frame identity for two invocations on one source line. |
| `fibonacci` | A return value attributed to the wrong invocation. |
| `deep-recursion` | — frame identity at depth 100. |
| `prologue` | An argument read at the signature line, before the prologue ran, reported as a value. |
| `uninitialised-local` | Stack garbage shown as a value. |

## Failure and limits

| Fixture | What it pins |
|---|---|
| `segfault` | The target dies. The steps before the fault stay valid and the signal is named. |
| `index-out-of-range` | The runtime's bounds check panics. A partial trace is not presented as a complete one. |
| `infinite-loop` | Bounded by `steps` and `wall_ms`. **Built but never run by the fixture sweep.** |
| `corrupt-length` | Thirty plausible elements read from a corrupt length. |
| `many-objects` | Past `objects_per_step` = 200. Enforced by the core, not the adapter. |
| `long-string` | Past `string_length` = 256 **bytes**. |
| `long-trace` | Past `steps` = 2500, with a budget check that stays O(new data). |
| `spawns-thread` | Memory written by another thread drawn as if a shown line produced it. |

## Output

| Fixture | What it pins |
|---|---|
| `prints-in-loop` | Two streams from one run. Neither is lost or reordered. |
| `prints-utf8` | **Not optional** ([SPEC-TEST-030](../../docs/TEST-STRATEGY.md#spec-test-030)). A character count measured against a byte limit. 9 characters, 13 bytes. |

## Measured behaviour, 2026-08-05

Odin `dev-2026-07-nightly:819fdc7`, Ubuntu 24.04, x86-64. All 34 compile. All
but `infinite-loop` were run.

| Fixture | Observed |
|---|---|
| `dangling-pointer` | Printed `2188748350937094558`. A plausible integer, **no error**. |
| `segfault` | `SIGSEGV`, exit 139, after its first line printed. |
| `index-out-of-range` | The runtime panic, exit 132. |
| `sub-slice` | Lengths 3 and 2, as specified. |
| `prints-utf8` | 13 bytes for 9 characters. |
| `free-then-allocate` | Reuse confirmed: the second allocation lands on the first's address. |
| `truncated-then-restored` | Resizing down keeps the same data pointer. |

### Two findings that changed a fixture

**`free-then-allocate` needed a warm-up loop, or it tested nothing.**
The obvious shape does not reuse the address on this toolchain:

| Shape | Reuse |
|---|---|
| `new`, `free`, `new`, 20 cycles | no — 20 different addresses |
| `new`, `new`, free the first, `new`, from a cold allocator | no |
| 8 live allocations, free the middle one, `new` | no |
| 16 allocated and freed first, then the above | **yes, every run** |

The allocator hands out fresh addresses until enough blocks have been returned
to it. The threshold measured between 4 and 8 freed 8-byte blocks. The fixture
uses 16.

This matters beyond the fixture. Without the loop the two objects get different
addresses, so they get different identities anyway, and the test meant to pin
the version 1 incorrectness would pass while asserting nothing — the same
vacuous-check failure [SPEC-TEST-022](../../docs/TEST-STRATEGY.md#spec-test-022)
was written against.

It also narrows the claim in [SPEC-MEM-042](../../docs/MEMORY-MODEL.md#spec-mem-042):
the known incorrectness is real, but a student meets it only after their program
has already freed a number of allocations. That is a specification question, not
a code one, and it is raised rather than resolved here
([AGENT-GUIDE](../../docs/AGENT-GUIDE.md) Rule 3).

**`dangling-pointer` confirms [R-21](../../docs/RISKS.md#r-21) again.**
The freed region read back as an ordinary integer with no error, on a second
toolchain. The fixture asserts the value is shown as an ordinary value, because
asserting `unreadable` would encode a detection the tool does not have.

## Toolchain note

This sweep ran on Odin `dev-2026-07-nightly:819fdc7` and GNU gdb
`15.0.50.20240403-git`. Neither matches the supported row in
[PLATFORM-SUPPORT.md](../../docs/PLATFORM-SUPPORT.md) §5, which is Odin
`dev-2026-08:9caff63` with gdb 15.1. Under
[SPEC-PLAT-030](../../docs/PLATFORM-SUPPORT.md#spec-plat-030) that is the "not
listed" case: warn, record the versions, continue.

Nothing here adds a row to the compatibility table. A row needs the probe suite,
and the probe suite is the other half of Phase 0.
