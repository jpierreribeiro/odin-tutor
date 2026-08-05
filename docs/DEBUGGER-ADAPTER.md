# DEBUGGER-ADAPTER

How the tool drives a debugger, and what an adapter must satisfy.

---

## 1. The adapter interface

An adapter is a program. The core starts it, waits for it, and reads its output
files. The interface is a process contract, not a code interface.

<a id="spec-adp-001"></a>
### SPEC-ADP-001 — Invocation
The core invokes an adapter as:

```
<adapter-command> --executable <path> --source <file> --entry <symbol>
                  --out <observations.jsonl>
                  --stdout <file> --stderr <file>
                  --budgets <json-file>
```

<a id="spec-adp-002"></a>
### SPEC-ADP-002 — Exit status
The adapter exits with the target program's exit status, adjusted for a signal
in the shell convention (`128 + signal`). It does not exit with the debugger's
status.

*Rationale:* the core then classifies the target program by the same rule a
plain execution would use. A prior system whose tracer always exited zero
reported "success" for a program that had crashed.

<a id="spec-adp-003"></a>
### SPEC-ADP-003 — Failure of the adapter itself
When the adapter cannot start the debugger or cannot proceed, it writes a header
record and an error record, and exits with a status of 125. The core maps 125 to
`DEBUGGER_FAILED`.

*Rationale:* 125 is outside the range a normal program uses for its own exit
codes in these exercises, and the observation file distinguishes the case
anyway. The status is a fast path, not the only signal.

<a id="spec-adp-004"></a>
### SPEC-ADP-004 — An adapter is declared, not discovered
Adapters are listed in the compatibility matrix
([PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md)). There is no plugin search path.

*Rationale:* an adapter reads the memory of a process. Discovering one from the
environment is a path to running an unexpected program.

---

## 2. Adapter `gdb-python/1`

The only adapter in version 1.

### 2.1 Mechanism

GDB embeds a Python interpreter and exposes typed values through it. The adapter
is a Python script that GDB executes in batch mode.

```
gdb --batch -nx --quiet -x adapter.py <executable>
```

| Flag | Reason |
|---|---|
| `--batch` | Run the script and exit. Never present a prompt. |
| `-nx` | Ignore any `.gdbinit`. The working directory must not be able to script the debugger. |
| `--quiet` | No banner in the captured output. |

Configuration reaches the script through the environment, never through the
command line, so no path from the exercise appears in an argument vector.

<a id="spec-adp-014"></a>
### 2.2 SPEC-ADP-014 — Stepping is confined to the student's source

A plain `step` loop **does not** stay in the student's code. This is measured,
not feared: over 120 steps of a small program, 42 stops — 35% — landed in
`base/runtime/heap_allocator.odin`, `internal.odin`, `core_builtin.odin`,
`error_checks.odin`, and glibc's `memset` assembly.
[Probe report, 2026-08-05](../fixtures/toolchain/2026-08-05-linux-x86_64.md).

The adapter therefore runs this loop:

```
at every stop:
    read the stopped frame's source file
    if it is not a file the student authored:
        finish            ← leave the whole call in one operation
        continue the loop without recording a step
    record the step
    step
```

*Why `finish` and not `next`:* `next` would step over the runtime call one line
at a time from inside it. `finish` leaves the entire call at once, which is why
the confined loop costs **no more per student step** than the naive one: 1.31 ms
either way, with 4 escapes replacing 42 wasted stops.

This realises [REQ-FRAME-001](REQUIREMENTS.md#req-frame-001). Without it, the
step budget is spent inside `fmt.println` and the student's program never
finishes.

### 2.3 Why a script inside GDB, and not GDB/MI over a pipe

Both were considered. See [ADR-004](decisions/ADR-004-in-debugger-extractor.md).

| | GDB/MI over a pipe | Script inside GDB |
|---|---|---|
| Our code is 100% Odin | yes | no |
| Typed access to values | no; values arrive as text and are re-parsed | yes |
| Round trips per step | many | none |
| A length can be validated **before** it sizes a read | no; the read already happened | yes |
| Fragility to debugger output formatting | high | low |

The deciding item is the fourth.
[REQ-SAFE-002](REQUIREMENTS.md#req-safe-002) requires that a length read from a
possibly-corrupt target is validated before it controls a read. Over MI the
value arrives already rendered, so the check happens after the fact, and a
corrupt length has already been acted on.

The cost is accepted and bounded: the script implements
[OBSERVATION-SPEC.md](OBSERVATION-SPEC.md) and nothing else. It contains no
identity logic, no encoding, and no presentation.

### 2.3 Stepping

1. Break on the entry symbol.
2. Run, with the target's output redirected to the two files the core named.
3. Loop:
   - if the stop is inside the student's file, record a step, then `step`;
   - otherwise `finish`, to leave library code without spending a step.
4. Stop when the program ends, when the step budget is reached, or when the wall
   budget is reached.
5. Let the program run to completion, so that its remaining output is flushed.

<a id="spec-adp-010"></a>
### SPEC-ADP-010 — Library frames produce no step
A stop outside the exercise's source files produces no observation record. This
satisfies [REQ-FRAME-001](REQUIREMENTS.md#req-frame-001).

*Rationale:* stepping into `fmt.println` produces frames whose values are read
from memory the student never wrote, and consumes the step budget with material
that teaches nothing.

<a id="spec-adp-011"></a>
### SPEC-ADP-011 — An inner budget bounds the stepping loop
The loop has its own iteration budget, larger than the step budget, so that a
program which spends its time inside library code cannot loop without end.

<a id="spec-adp-012"></a>
### SPEC-ADP-012 — Output separation
The target process's output is redirected at the point the program starts, so
the debugger's own output never mixes with it.

*Rationale:* the debugger announces every stop. Without redirection those
announcements interleave with the program's output, and the program's real
output is unreadable.

### 2.4 Compiler-injected names

Odin injects a `context` value into every procedure frame. The adapter drops it.
It is the compiler's, not the student's.

<a id="spec-adp-013"></a>
### SPEC-ADP-013 — The dropped-name list is explicit
Names the adapter drops are listed in one place in the script and are documented
here. Adding a name requires an ADR.

*Rationale:* hiding a name is hiding information from the student. It needs a
reason each time.

---

## 3. Future adapters

### `lldb-python` (macOS)
LLDB exposes a Python API comparable to GDB's. The mechanism transfers. The
obstacles are platform ones, not interface ones: code signing, and the security
policy for debugging another process. See
[PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md) §3.

`lldb-mi` is not a path. It is unmaintained.

### `native-linux` (no external debugger)
An adapter written in Odin that uses `ptrace`, reads ELF, and parses DWARF.

It would remove the last non-Odin component and the debugger dependency on
Linux. It requires:

| Part | Size |
|---|---|
| `ptrace` control, wait status handling, breakpoints | moderate |
| ELF section reading | small |
| DWARF: abbreviations, compile units, DIE tree | moderate |
| DWARF: type graph for base, struct, pointer, array, typedef | moderate |
| DWARF: line table state machine | moderate |
| DWARF: location expressions, at least `DW_OP_fbreg` and `DW_OP_addr` | small, but exacting |

It is [ROADMAP.md](ROADMAP.md) Phase 7 and is optional. The project does not
depend on it. It is listed so that the adapter interface stays narrow enough to
admit it.

<a id="spec-adp-020"></a>
### SPEC-ADP-020 — A new adapter is proven against the fixture set
A new adapter is accepted when it produces observation records that lead the
core to the same trace as the reference adapter, for every fixture program.
Differences must be explained in the adapter's own document, not absorbed
silently.

---

## 4. What every adapter must satisfy

Restated from [OBSERVATION-SPEC.md](OBSERVATION-SPEC.md) §6 and §7, because an
adapter author reads this document first.

**Must**

- enforce read-time budgets and declare them;
- wrap every read so failure produces `unreadable`;
- validate a length before it sizes a read;
- emit records in order with a monotonic index;
- separate the target's output from the debugger's;
- exit with the target's status;
- record its own failure rather than exiting silently.

**Must not**

- assign logical identity;
- decide aliasing;
- emit deltas;
- read through an unshaped pointer;
- emit presentation data;
- invent a value.

---

## 5. Known unknowns for the GDB adapter

These are not yet validated. See [RISKS.md](RISKS.md).

| Unknown | Class | How to validate |
|---|---|---|
| Odin's DWARF quality on the pinned toolchain | ~~BLOCKING~~ | **Answered 2026-08-05.** Entry symbol, line table, struct fields, slice fields all pass. DWARF 4, not 3. Entry symbol is `main::main`. |
| Frame key availability (`caller_pc`, `caller_sp`) through GDB's Python API | ~~HIGH~~ | **Answered.** Stable at depth 7. Two calls on one line gave two return addresses. |
| Whether `FinishBreakpoint` is reliable for return values on this toolchain | ~~HIGH~~ | **Answered.** 25 of 25 correct on `fib(6)`, none wrong. One caveat: `stop()` must return `False` on a recursive procedure that also carries an ordinary breakpoint. |
| Cost per step, and therefore the wall budget | ~~MEDIUM~~ | **Measured.** 1.31 ms per student step. |
| Behaviour when the target is stripped or built without debug information | ~~MEDIUM~~ | **Answered.** A stripped executable does not crash GDB and produces no error of its own. The detection is `lookup_global_symbol("main::main")` returning `None`, where a normal build returns the symbol. The adapter raises `DEBUG_INFO_MISSING` from that check. |
| Whether map entries are reachable | **HIGH, landed** | The type exposes only `['data', 'len', 'allocator']`. [R-20](RISKS.md#r-20). |
| Whether a short-lived thread is detectable | **HIGH, answered** | Not by counting. `gdb.events.new_thread` catches it; a per-stop count never fires. [ADR-012](decisions/ADR-012-single-threaded-target.md). |
| Whether use-after-free is detectable by reading | **Answered: no** | The freed region stays mapped and reads as plausible garbage. [R-21](RISKS.md#r-21). |
| Whether stepping stays in the student's source | ~~HIGH~~ | **Answered: it does not.** 35% of stops landed elsewhere. Mitigation adopted as [SPEC-ADP-014](#spec-adp-014). |

Every row above is answered **on one combination**. See
[ADR-009](decisions/ADR-009-toolchain-pinning.md) for why that is not the same as
answered.
