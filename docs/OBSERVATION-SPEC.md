# OBSERVATION-SPEC

The contract between the adapter and the core.

Format name: `odin-tutor-observation`
Current version: `1`

---

## 1. Purpose

An observation record is what the adapter saw at one step. It is raw:

- it contains addresses;
- it contains no logical identity;
- it contains no delta encoding;
- it contains no sharing analysis;
- it makes no claim about aliasing.

The core turns a stream of observation records into a trace. Everything the
project reasons about lives on the core's side of this line. See
[ARCHITECTURE.md](ARCHITECTURE.md) §4.

---

## 2. Transport

<a id="spec-obs-001"></a>
### SPEC-OBS-001 — Line-delimited records
The adapter writes one JSON object per line to `run/observations.jsonl`. The
first line is a header record. Every later line is a step record.

*Rationale:* the adapter can append while running, so a run that is interrupted
still yields the steps that completed. A truncated final line is detectable and
is discarded without losing earlier lines.

<a id="spec-obs-002"></a>
### SPEC-OBS-002 — The core tolerates a truncated tail
The core discards a final line that does not parse, and records
`ADAPTER_PROTOCOL_ERROR` as a note, not as a fatal error. Every complete line
before it is used.

<a id="spec-obs-003"></a>
### SPEC-OBS-003 — A malformed record in the middle is fatal
A line that does not parse and is not the last line is
`ADAPTER_PROTOCOL_ERROR` and stops trace assembly. The partial trace is still
written, with the error recorded.

*Rationale:* a gap in the middle means the step sequence is not what it claims.
Continuing would silently present step *n+1* as if it followed step *n*.

---

## 3. Header record

```jsonc
{
  "record": "header",
  "format": "odin-tutor-observation",
  "version": 1,
  "adapter": "gdb-python/1",
  "debugger_version": "GNU gdb (Debian 15.1-1) 15.1",
  "target": { "file": "main.odin", "entry": "main.main" },
  "budgets": { "elements": 30, "fields": 30, "string_length": 256,
               "objects_per_step": 200, "expansions_per_step": 32,
               "expansions_total": 600, "sane_length": 1000000 }
}
```

<a id="spec-obs-010"></a>
### SPEC-OBS-010 — The adapter declares the budgets it enforced
The adapter states the read-time budgets it applied. The core checks them
against its own configuration and records `ADAPTER_PROTOCOL_ERROR` when they
disagree.

*Rationale:* a budget enforced at the read cannot be verified after the fact.
Declaring it makes the disagreement detectable instead of invisible.

---

## 4. Step record

```jsonc
{
  "record": "step",
  "index": 11,
  "event": "line" | "call" | "return" | "terminated",
  "file": "main.odin",
  "line": 14,
  "stdout_bytes": 12,

  "frames": [
    {
      "procedure": "main.sum_grades",
      "file": "main.odin",
      "line": 14,
      "declared_line": 10,
      "frame_key": { "caller_pc": 4198912, "caller_sp": 140737488347000 },
      "variables": [
        { "name": "total", "declared_line": 11, "is_parameter": false,
          "read": { "ok": true, "value": { /* §5 */ } } },
        { "name": "xs", "declared_line": 10, "is_parameter": true,
          "read": { "ok": true, "value": { /* §5 */ } } },
        { "name": "n", "declared_line": 16, "is_parameter": false,
          "read": { "ok": false, "reason": "not_reached" } }
      ]
    }
  ],

  "returned": { "frame_key": { "caller_pc": 4198912, "caller_sp": 140737488347000 },
                "value": { /* §5 */ } },

  "limits_hit": ["elements"]
}
```

<a id="spec-obs-020"></a>
### SPEC-OBS-020 — The adapter reports position facts, not conclusions
The adapter reports `line`, `declared_line`, and `is_parameter`. It does **not**
decide `not-yet-active`. The core applies
[SPEC-MEM-021](MEMORY-MODEL.md#spec-mem-021).

*Rationale:* the rule is pedagogy. Pedagogy belongs in the core, where it is
tested without a debugger.

Exception: the adapter **must not read** a variable it can tell is not yet
active, because reading it is pointless and costs time. It reports
`{"ok": false, "reason": "not_reached"}`. The core still decides how to present
it. The adapter's skip is an optimisation; the core's decision is the contract.

<a id="spec-obs-021"></a>
### SPEC-OBS-021 — `frame_key` is raw
`frame_key` carries the caller's program counter and stack pointer as integers.
The core turns the pair into a frame identity
([SPEC-MEM-060](MEMORY-MODEL.md#spec-mem-060)). The adapter does not name
frames.

<a id="spec-obs-022"></a>
### SPEC-OBS-022 — `stdout_bytes` is bytes
The adapter reports bytes, because that is what it can cheaply observe from the
redirected output file. The core converts to code points for the trace
([SPEC-TRACE-010](TRACE-SPEC.md#spec-trace-010)) by decoding the captured
output.

*Rationale:* the unit conversion is a source of a real defect class. Naming the
unit in the field name on both sides makes a mismatch visible during review.

---

## 5. Value records

A value is one of the following. The adapter emits addresses. The core removes
them.

```jsonc
// scalar
{ "kind": "scalar", "type": "int", "text": "42" }

// pointer
{ "kind": "pointer", "address": 0, "target_type": "main.Node",
  "target_is_aggregate": true }

// aggregate occupying memory (struct, fixed array)
{ "kind": "aggregate", "type": "main.Student", "address": 140737488347008,
  "size": 40,
  "fields": [ { "name": "name", "value": { /* recursive */ } } ],
  "truncated": false }

// view (slice, string, dynamic array)
{ "kind": "view", "type": "[]int",
  "self_address": 140737488347040,
  "data_address": 94237891231744,
  "length": 3, "capacity": null,
  "length_sane": true,
  "elements": [ { /* recursive */ } ],
  "truncated": false }

// text
{ "kind": "text", "type": "string",
  "self_address": 140737488347056,
  "data_address": 94237891231800,
  "length": 3, "length_sane": true,
  "text": "Ana", "truncated": false }

// not represented
{ "kind": "opaque", "type": "map[string]int", "reason": "runtime_layout",
  "entry_count": 2 }
{ "kind": "unreadable", "reason": "address not mapped" }
```

<a id="spec-obs-030"></a>
### SPEC-OBS-030 — `self_address` and `data_address` are both required for a view
`self_address` is where the view value lives. `data_address` is where its
elements live. The core needs both:
`data_address` gives storage identity; `self_address` gives identity when
`data_address` is null ([SPEC-MEM-012](MEMORY-MODEL.md#spec-mem-012)).

An adapter that omits `self_address` makes the empty-view rule impossible to
apply. The core rejects such a record with `ADAPTER_PROTOCOL_ERROR`.

<a id="spec-obs-031"></a>
### SPEC-OBS-031 — `length_sane` records the validation, not the result of ignoring it
When a length fails validation the adapter emits `length_sane: false`, omits
`elements`, and does not truncate silently. The core then produces `unknown`
([SPEC-MEM-013](MEMORY-MODEL.md#spec-mem-013)).

<a id="spec-obs-032"></a>
### SPEC-OBS-032 — `truncated` distinguishes a budget from a short value
`truncated: true` means a budget stopped the adapter, not that the value is
short. A collection of two elements with a budget of thirty is
`truncated: false`.

<a id="spec-obs-033"></a>
### SPEC-OBS-033 — No value is ever invented
When the adapter cannot produce a truthful value it emits `unreadable` or
`opaque` with a reason. It never emits a placeholder that looks like a value.

---

## 6. What the adapter must not do

| Prohibited | Reason |
|---|---|
| Assign logical identity | The core owns identity ([SPEC-MEM-002](MEMORY-MODEL.md#spec-mem-002)) |
| Decide that two values are aliases | The core owns it, and it needs cross-step state |
| Emit deltas | Encoding is the core's ([SPEC-TRACE-001](TRACE-SPEC.md#spec-trace-001)) |
| Read through an unshaped pointer | [SPEC-MEM-031](MEMORY-MODEL.md#spec-mem-031) |
| Read a length-driven region before validating the length | [SPEC-MEM-013](MEMORY-MODEL.md#spec-mem-013) |
| Emit presentation data | [REQ-TRACE-006](REQUIREMENTS.md#req-trace-006) |
| Continue after an internal exception without recording it | Silence hides a gap |

---

## 7. What the adapter must do

| Obligation | Reason |
|---|---|
| Enforce read-time budgets | Only the adapter can; the read is there |
| Wrap every read so a failure yields `unreadable` | [REQ-SAFE-001](REQUIREMENTS.md#req-safe-001) |
| Emit one record per step, in order, with a monotonic index | The core relies on order |
| Redirect the target's output away from the debugger's own | [REQ-EXEC-005](REQUIREMENTS.md#req-exec-005) |
| Exit with the target program's status, not its own | The core classifies the program by the same rule as a plain run |
| Declare its own version and the debugger's version | [SPEC-OBS-010](#spec-obs-010) |

---

## 8. Fixtures

Recorded observation streams are the core's primary test input. See
[TEST-STRATEGY.md](TEST-STRATEGY.md) §3.

A fixture is a directory:

```
fixtures/observations/two-empty-slices/
  program.odin          the source that produced it
  observations.jsonl    the recorded stream
  toolchain.json        the versions that produced it
  expected-trace.json   the trace the core must produce
```

<a id="spec-obs-040"></a>
### SPEC-OBS-040 — A fixture is regenerated, never edited
A fixture is produced by running the adapter. It is not written by hand and is
not edited. When the observation format changes, fixtures are regenerated and
the diff is reviewed.

*Rationale:* a hand-edited fixture can encode a shape the adapter never emits,
and the resulting test proves nothing about the real system.
