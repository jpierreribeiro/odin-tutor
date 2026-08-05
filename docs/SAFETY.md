# SAFETY

What the tool defends against, and what it does not.

This document is named SAFETY, not SECURITY, on purpose. See §1.

---

## 1. Threat model

### What this is not

The tool runs the student's own program on the student's own machine. The
student could run that program directly. **The tool provides no security
boundary, and does not claim one.** There is no sandbox
([ADR-001](decisions/ADR-001-local-first-no-backend.md)).

Adding a sandbox would protect the student from the student. It would add
platform-specific containment code, and it would suggest a guarantee that does
not exist.

### What this is

The target program is **untrusted input to the tracer**. Not because the student
is hostile, but because a learner's program is *wrong*, and a wrong program in a
manual-memory language produces exactly the inputs that break a naive reader:

| Input | Source |
|---|---|
| an invalid pointer | a bug the student is trying to find |
| a dangling pointer | use after free |
| a corrupt length field | a buffer overrun |
| uninitialised memory | reading before assignment |
| an enormous allocation | a loop bound mistake |
| an infinite loop | the classic |
| a segmentation fault | any of the above |
| unexpected debug information | a compiler version change |

A tool that crashes on these is useless precisely when the student needs it. A
tool that *reports plausible values* from these is worse than useless.

<a id="spec-safe-001"></a>
### SPEC-SAFE-001 — The tracer fails closed
Every read of target memory has a defined failure path that produces
`unreadable` and continues. No read may terminate the tool.
[REQ-SAFE-001](REQUIREMENTS.md#req-safe-001).

<a id="spec-safe-002"></a>
### SPEC-SAFE-002 — The tracer never repairs
The tool does not correct a value it believes is wrong, does not clamp a length
into range, and does not skip a corrupt field silently. It reports.

---

## 2. The rule that governs every read

```
        a value from the target
                 │
                 ▼
        can it be interpreted truthfully?
           │              │
          yes             no
           │              │
           ▼              ▼
         report        report unknown / unreadable
         the value     with a reason
```

There is no third branch. There is no "best guess" branch.

<a id="spec-safe-010"></a>
### SPEC-SAFE-010 — A length is validated before it is used
A length or count read from the target is checked against `MAX_SANE_LENGTH`
before it drives any loop or sizes any read.
[REQ-SAFE-002](REQUIREMENTS.md#req-safe-002),
[SPEC-MEM-013](MEMORY-MODEL.md#spec-mem-013).

An unchecked length is an arbitrary-size read. This is the single most important
rule in the adapter.

<a id="spec-safe-011"></a>
### SPEC-SAFE-011 — A failed length produces `unknown` for the whole value
The adapter does not read `min(length, budget)` elements from a value whose
length failed validation. It reports `unknown`.

*Rationale:* reading thirty elements from a value claiming four billion produces
thirty plausible numbers and hides the corruption that the student is looking
for.

<a id="spec-safe-012"></a>
### SPEC-SAFE-012 — A pointer with no declared shape is never followed
[SPEC-MEM-031](MEMORY-MODEL.md#spec-mem-031).

---

## 3. Where each budget is enforced

A budget is enforced where it can be enforced, which is not always where it is
declared.

| Budget | Enforced by | Why there |
|---|---|---|
| elements per collection | adapter | the read happens there |
| fields per object | adapter | same |
| string length | adapter | same |
| pointer expansions per step | adapter | same |
| pointer expansions per trace | adapter | needs cross-step state inside the run |
| sane length | adapter | must precede the read |
| objects per step | core | it is a property of the assembled step |
| steps | adapter and core | the adapter stops stepping; the core enforces the recorded count |
| trace bytes | core | the trace is the core's artefact |
| wall time | adapter and core | both can exceed it |

<a id="spec-safe-020"></a>
### SPEC-SAFE-020 — The adapter declares what it enforced
[SPEC-OBS-010](OBSERVATION-SPEC.md#spec-obs-010). The core compares the declared
budgets with its configuration and reports a disagreement. A budget enforced at
the read cannot be verified afterwards, so the declaration is the only check
available.

---

## 4. Budget values

Version 1 defaults. Each is configurable. Each has a reason.

| Budget | Default | Reason |
|---|---|---|
| `steps` | 2500 | An exercise that needs more is too large to teach from. |
| `objects_per_step` | 200 | Beyond this the picture is unreadable regardless of the terminal. |
| `fields` | 30 | A struct with more fields is not a teaching example. |
| `elements` | 30 | Same. |
| `string_length` | 256 | A longer string is not read on screen. |
| `expansions_per_step` | 32 | Bounds the per-step cost of following pointers. |
| `expansions_total` | 600 | Pointer expansion cost is steps × expansions. A per-step bound alone still allows a long loop to become quadratic. A prior system measured 20 nodes at 1.7 s, 40 at 3.4 s, 80 at 12 s, and 150 as a timeout. |
| `sane_length` | 1 000 000 | Above this a length is treated as corrupt, not as large. |
| `trace_bytes` | 32 MiB | Local, so this is generous. It exists to catch a runaway, not to compress. |
| `wall_ms` | 60 000 | An exercise that traces for a minute is not an exercise. |

<a id="spec-safe-030"></a>
### SPEC-SAFE-030 — Every budget degrades honestly
Reaching a budget produces a valid trace with a truncation record, visible at
the step. [REQ-SAFE-004](REQUIREMENTS.md#req-safe-004),
[REQ-SAFE-005](REQUIREMENTS.md#req-safe-005).

<a id="spec-safe-031"></a>
### SPEC-SAFE-031 — A budget must never produce an invalid document
Two failures of this kind are known from a prior system and are called out so
the same mistakes are not repeated.

1. **A cap measured in the wrong unit.** A budget counted characters while the
   consumer's limit counted bytes. Any text outside ASCII made the produced
   document exceed the limit, and it was then cut mid-document. The result did
   not parse: the whole trace was lost rather than truncated.
   *Rule:* a budget and the limit it protects use the same unit, and the unit is
   in the field name.

2. **A cap whose own measurement was quadratic.** The size check re-serialised
   the entire accumulated document at every step. At the step limit, measuring
   cost more than the whole time budget, so the step limit could never be
   reached: a long trace failed by timeout inside the measuring code.
   *Rule:* a budget check is O(1) or O(new data), never O(total).
   [REQ-PERF-002](REQUIREMENTS.md#req-perf-002).

<a id="spec-safe-032"></a>
### SPEC-SAFE-032 — The final document is measured, not estimated
Before writing, the core measures the encoded trace and reduces it if it exceeds
the byte budget. An incremental estimate is a cheap early stop, not the
guarantee.

---

## 5. Non-memory safety

<a id="spec-safe-040"></a>
### SPEC-SAFE-040 — The debugger is not scriptable from the working directory
The debugger is invoked with the flag that ignores an initialisation file, so a
file in the exercise directory cannot script it.
[DEBUGGER-ADAPTER.md](DEBUGGER-ADAPTER.md) §2.1.

*Rationale:* this is the one place where the local model still needs care. A
student who downloads an exercise from a third party would otherwise be running
that party's debugger commands.

<a id="spec-safe-041"></a>
### SPEC-SAFE-041 — Exercise content is data
[SPEC-EX-001](EXERCISE-SPEC.md#spec-ex-001). An exercise cannot run a script and
cannot change the build.

<a id="spec-safe-042"></a>
### SPEC-SAFE-042 — Configuration reaches the adapter through the environment
No path from an exercise appears in a command-line argument vector.

<a id="spec-safe-043"></a>
### SPEC-SAFE-043 — The tool writes only where it says
[REQ-GEN-002](REQUIREMENTS.md#req-gen-002).

---

## 6. Resource exhaustion of the host

The target program is a normal process. It can allocate until the machine
swaps, and it can loop forever.

<a id="spec-safe-050"></a>
### SPEC-SAFE-050 — The wall budget bounds the run
The adapter enforces `wall_ms` and terminates the target process when it is
reached, producing `LIMIT_WALL_TIME` and a valid trace of what happened first.

<a id="spec-safe-051"></a>
### SPEC-SAFE-051 — Memory is not bounded in version 1
The tool does not place a memory limit on the target process. A student's
allocation loop can exhaust the machine's memory, exactly as it would without
the tool.

This is a **stated non-goal**, not an oversight. Bounding it means a per-platform
mechanism, and the tool offers no protection the operating system does not
already offer for a program the student ran themselves.

The documentation says this plainly rather than implying protection.

---

## 7. Privacy

<a id="spec-safe-060"></a>
### SPEC-SAFE-060 — Nothing leaves the machine
No telemetry, no crash reporting, no update check, no network access at all.
[REQ-GEN-001](REQUIREMENTS.md#req-gen-001).

An automated test runs the full suite with networking disabled.
