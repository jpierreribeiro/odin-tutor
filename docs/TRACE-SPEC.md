# TRACE-SPEC

The trace format. This is the contract between the model and every consumer.

Format name: `odin-tutor-trace`
Current version: `1`

---

## 1. Design constraints

| Constraint | Source |
|---|---|
| Backward navigation must not re-execute | [REQ-TRACE-001](REQUIREMENTS.md#req-trace-001) |
| Random access to any step | [REQ-TRACE-003](REQUIREMENTS.md#req-trace-003) |
| Valid document under truncation, crash, and adapter failure | [REQ-TRACE-005](REQUIREMENTS.md#req-trace-005) |
| No presentation data | [REQ-TRACE-006](REQUIREMENTS.md#req-trace-006) |
| Identity is logical, never an address | [REQ-MEM-001](REQUIREMENTS.md#req-mem-001) |
| Usable later by a web interface, an editor plugin, and the validator | [PROJECT.md](PROJECT.md) §7 |

---

## 2. Encoding: keyframes and deltas

<a id="spec-trace-001"></a>
### SPEC-TRACE-001 — Hybrid encoding
The stored trace is a sequence of steps. A step is a **keyframe** or a
**delta**. Step 0 is always a keyframe. A keyframe occurs at least every `K`
steps. The default `K` is 32.

### The analysis behind this

Three encodings were considered.

| | Full snapshots | Pure delta | Keyframe + delta |
|---|---|---|---|
| Memory, 2500 steps × 4 KB | ~10 MB | ~1 MB | ~1.3 MB |
| Serialisation cost | highest | lowest | low |
| Random access to step *n* | O(1) | O(*n*) replay | O(*K*) replay |
| Backward navigation | O(1) | O(*n*) or keep all materialised | O(*K*) |
| One corrupt step damages | that step | every later step | that keyframe interval |
| Readable by a human during debugging | yes | poorly | at keyframes |
| Reusable over a network later | wasteful | ideal | good |

**The local-first decision changes the usual answer.** There is no network and
no wire budget, so the pressure that normally forces pure delta is absent. Full
snapshots would be acceptable on memory alone.

Pure delta is rejected for two reasons that matter more here than size:
random access is the *primary* operation in a step player with a jump command,
and a single bad delta poisons every step after it, which is the worst possible
failure mode for a tool whose purpose is trustworthiness.

Keyframes bound both. `K = 32` means a jump costs at most 31 delta applications
of a small object, which is far below the latency budget, and corruption is
contained to at most 32 steps.

`K` is configurable. `K = 1` yields full snapshots and is a supported debugging
mode.

*Decision record:* [ADR-005](decisions/ADR-005-trace-encoding.md).

<a id="spec-trace-002"></a>
### SPEC-TRACE-002 — Materialisation is defined, not implied
To materialise step *n*: take the greatest keyframe index *k* ≤ *n*, then apply
the deltas for *k+1* … *n* in order. The result must equal what a full snapshot
at *n* would contain. A test asserts this for every fixture with `K = 32`
against the same fixture with `K = 1`.

<a id="spec-trace-003"></a>
### SPEC-TRACE-003 — A delta is a set of replacements and removals
A delta names entities to add or replace, and entities to remove. It does not
express partial edits inside an entity. An entity that changes is emitted whole.

*Rationale:* whole-entity replacement makes materialisation trivially correct
and makes a delta readable. The size saving from field-level deltas is not worth
the class of bug it invites.

---

## 3. Document structure

```jsonc
{
  "format": "odin-tutor-trace",
  "version": 1,

  "run": {
    "source_files": ["main.odin"],
    "entry": "main.main",
    "toolchain": {
      "odin": "dev-2026-08",
      "debugger": "gdb 15.1",
      "adapter": "gdb-python/1"
    },
    "keyframe_interval": 32
  },

  "outcome": {
    "kind": "exited" | "signalled" | "not_started",
    "exit_code": 0,
    "signal": "SIGSEGV",
    "message": "Index 10 is out of range 0..<3"
  },

  "budgets": {
    "steps":            { "limit": 2500,    "reached": false },
    "objects_per_step": { "limit": 200,     "reached": false },
    "fields":           { "limit": 30,      "reached": false },
    "elements":         { "limit": 30,      "reached": true  },
    "string_length":    { "limit": 256,     "reached": false },
    "expansions":       { "limit": 600,     "reached": false },
    "trace_bytes":      { "limit": 33554432,"reached": false },
    "wall_ms":          { "limit": 60000,   "reached": false }
  },

  "errors": [ /* see §8 */ ],

  "steps": [ /* see §4 */ ]
}
```

<a id="spec-trace-004"></a>
### SPEC-TRACE-004 — `outcome` describes the program, not the tool
`outcome` says how the *target program* ended. A failure of the tool appears in
`errors`, never here. See [REQ-ERR-001](REQUIREMENTS.md#req-err-001).

<a id="spec-trace-005"></a>
### SPEC-TRACE-005 — Budgets are always present
Every budget appears with its limit and whether it was reached, in every trace,
including traces where none was reached. A consumer must not have to infer a
budget's existence.

---

## 4. A step

```jsonc
{
  "index": 11,
  "encoding": "keyframe" | "delta",

  "event": "call" | "line" | "return" | "terminated",
  "location": { "file": "main.odin", "line": 14 },
  "stdout_chars": 12,

  "frames": [ /* outermost first; see §5 */ ],

  "objects": { /* identity -> object; see §6 */ },
  "views":   { /* identity -> view;   see §6 */ },
  "storages":{ /* identity -> storage; see §6 */ },

  "removed": ["obj-7", "view-2"],     // delta encoding only

  "truncated": ["objects_per_step"],  // budgets reached at THIS step
  "notes": ["frame-3 has variables that are not yet active"]
}
```

<a id="spec-trace-010"></a>
### SPEC-TRACE-010 — `stdout_chars` counts code points
`stdout_chars` is the number of Unicode code points that the target program had
written to standard output before this step. A consumer shows the output at a
step by taking that many code points from the captured output.

The count may lag the true value when the target's runtime buffers its output.
It must never lead it. A count that lags shows a shorter prefix, which is text
the program really wrote. A count that leads would show output before it
happened.

*Rationale for code points rather than bytes:* the consumer slices text, not
bytes. A byte count would split a multi-byte character. A prior system counted
characters against a byte limit and produced a document cut in the middle of a
multi-byte character.

<a id="spec-trace-011"></a>
### SPEC-TRACE-011 — `truncated` is per step
A budget reached at a step is named at that step, as well as in the document
header. The user interface shows it at the step
([REQ-SAFE-005](REQUIREMENTS.md#req-safe-005)).

---

## 5. A frame

```jsonc
{
  "id": "frame-3",
  "procedure": "sum_grades",
  "location": { "file": "main.odin", "line": 14 },
  "variable_state": "active" | "none" | "not_yet_active",
  "variables": {
    "total": { "state": "valid", "kind": "scalar", "type": "int", "text": "24" },
    "xs":    { "state": "valid", "kind": "ref",    "ref": "view-2" },
    "n":     { "state": "not-yet-active" },
    "p":     { "state": "valid", "kind": "pointer", "text": "nil" },
    "q":     { "state": "unreadable", "reason": "address not mapped" },
    "big":   { "state": "unknown", "reason": "elements budget reached" }
  },
  "returned": { "state": "unknown" } | { "state": "valid", "kind": "scalar", "text": "42" }
}
```

<a id="spec-trace-020"></a>
### SPEC-TRACE-020 — `variable_state` distinguishes three cases
| Value | Meaning |
|---|---|
| `active` | At least one variable is readable. |
| `none` | The procedure has no variables in scope. |
| `not_yet_active` | The procedure has variables, and none is readable yet. |

This satisfies [REQ-MEM-008](REQUIREMENTS.md#req-mem-008) and
[SPEC-MEM-022](MEMORY-MODEL.md#spec-mem-022).

<a id="spec-trace-021"></a>
### SPEC-TRACE-021 — `returned` is present only on a `return` event
`returned` with `state: "unknown"` means the tool could not attribute the value
to this invocation. It does not mean the procedure returned nothing. A procedure
with no return value has no `returned` field at all.

---

## 6. Objects, views, storages

```jsonc
"storages": {
  "sto-1": { "kind": "allocation" | "frame" | "global" | "unknown", "epoch": 0 }
},

"objects": {
  "obj-1": {
    "type": "Student",
    "storage": "sto-1",
    "fields": {
      "name":   { "kind": "ref", "ref": "view-3" },
      "grades": { "kind": "ref", "ref": "view-2" },
      "next":   { "kind": "ref", "ref": "obj-1" }     // a cycle
    },
    "truncated": false
  }
},

"views": {
  "view-2": {
    "type": "[]int",
    "storage": "sto-4",
    "offset": 0,
    "length": 3,
    "capacity": null,
    "elements": [
      { "kind": "scalar", "type": "int", "text": "7" },
      { "kind": "scalar", "type": "int", "text": "8" },
      { "kind": "scalar", "type": "int", "text": "9" }
    ],
    "truncated": false
  },
  "view-9": {
    "type": "[]int",
    "storage": null,
    "offset": 0,
    "length": 0,
    "elements": [],
    "empty_distinct": true
  }
}
```

<a id="spec-trace-030"></a>
### SPEC-TRACE-030 — Sharing is derivable and also stated
Two views with the same `storage` share storage. A consumer can derive that.
A materialised step also carries a convenience index:

```jsonc
"shared_storage": { "sto-4": ["view-2", "view-5"] }
```

It is derived data. A consumer may ignore it. It exists so that the user
interface and the validator do not each re-derive it.

<a id="spec-trace-031"></a>
### SPEC-TRACE-031 — `storage: null` means no storage
A view with `storage: null` and `empty_distinct: true` is an empty view whose
data pointer was null. Its identity came from its own location
([SPEC-MEM-012](MEMORY-MODEL.md#spec-mem-012)). Two such views are different
entities.

<a id="spec-trace-032"></a>
### SPEC-TRACE-032 — A pointer with no reference is a value, not a link
A pointer that the model did not resolve appears as
`{ "kind": "pointer", "text": "nil" }` or
`{ "kind": "pointer", "opaque": true }`. It carries no address by default
([SPEC-MEM-001](MEMORY-MODEL.md#spec-mem-001)).

---

## 7. Dangling references

<a id="spec-trace-040"></a>
### SPEC-TRACE-040 — A reference must resolve inside its own step
Every `ref` in a materialised step must name an entity present in that step. A
consumer that finds an unresolved reference must report `TRACE_INCONSISTENT` and
must not render the reference as if it pointed at nothing meaningful.

*Rationale:* when a budget drops an object, the reference to it would otherwise
survive and render as a link to nowhere. The student reads that as a statement
about the program. The model must instead replace the reference with
`{ "state": "unknown", "reason": "objects budget reached" }` at the point where
it drops the object.

This is a model obligation, not a consumer workaround.

---

## 8. Error taxonomy

Three origins. They never collapse into one class.
This satisfies [REQ-ERR-001](REQUIREMENTS.md#req-err-001).

### The program failed
| Class | Meaning |
|---|---|
| `PROGRAM_COMPILE_FAILED` | The target program did not compile. |
| `PROGRAM_EXITED_NONZERO` | The target program ran and exited with a non-zero code. |
| `PROGRAM_SIGNALLED` | The target program was terminated by a signal. |

These are not tool failures. A trace still exists for the last two.

### The tool failed to observe
| Class | Meaning |
|---|---|
| `TOOLCHAIN_MISSING` | A required external tool was not found. |
| `TOOLCHAIN_UNSUPPORTED` | A tool version is known to be incompatible. |
| `UNSUPPORTED_PLATFORM` | The platform is outside the support matrix. |
| `DEBUGGER_FAILED` | The debugger could not start, or stopped responding. |
| `DEBUG_INFO_MISSING` | The executable has no usable debug information. |
| `DEBUG_INFO_UNSUPPORTED` | The debug information is present but in a form the adapter does not handle. |
| `MEMORY_UNREADABLE` | A specific read failed. Attaches to a value, not to the run. |
| `TYPE_UNSUPPORTED` | A type has no truthful representation. Attaches to a value. |
| `ADAPTER_PROTOCOL_ERROR` | The adapter emitted something the core cannot read. |
| `TRACE_VERSION_UNSUPPORTED` | A consumer met a trace version it does not implement. |
| `TRACE_INCONSISTENT` | A trace violated an invariant, for example §7. |
| `INTERNAL_ERROR` | A defect in this tool. Always a bug report. |

### The tool deliberately omitted information
| Class | Meaning |
|---|---|
| `LIMIT_STEPS` | The step budget was reached. |
| `LIMIT_OBJECTS` | The per-step object budget was reached. |
| `LIMIT_FIELDS` | The per-object field budget was reached. |
| `LIMIT_ELEMENTS` | The per-collection element budget was reached. |
| `LIMIT_STRING` | The string-length budget was reached. |
| `LIMIT_EXPANSIONS` | The pointer-expansion budget was reached. |
| `LIMIT_TRACE_BYTES` | The trace-size budget was reached. |
| `LIMIT_WALL_TIME` | The wall-clock budget was reached. |

<a id="spec-trace-050"></a>
### SPEC-TRACE-050 — A `LIMIT_*` is not an error to the user
A `LIMIT_*` class means the tool worked correctly and chose to show less. The
user interface presents it as a notice, not as a failure. An `INTERNAL_ERROR`
presents as a failure with a request to report it.

---

## 9. Determinism

<a id="spec-trace-060"></a>
### SPEC-TRACE-060 — Fields excluded from determinism comparison
These may differ between two runs of the same input:

- `run.toolchain` (when versions differ)
- timing fields in `report.json`, which is not part of the trace

Everything else must be equal. Notably, **logical identities must be equal**,
because they are minted from a counter over a deterministic traversal order, not
from addresses.

<a id="spec-trace-061"></a>
### SPEC-TRACE-061 — Known sources of nondeterminism
| Source | Effect | Handling |
|---|---|---|
| Address-space randomisation | Addresses differ | Addresses are not identities, so no effect on the trace |
| Allocator behaviour | Address reuse patterns differ | May change epoch assignment; see [RISKS.md](RISKS.md) R-07 |
| Debugger version | Value formatting, symbol resolution | Pinned and checked; see [PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md) |
| Program input, clock, randomness | Program behaviour differs | Out of scope. Exercises must be deterministic; the loader warns on obvious sources. |
| Map iteration order in the target | Element order differs | Maps are not walked ([SPEC-MEM-052](MEMORY-MODEL.md#spec-mem-052)) |

---

## 10. Evolution

<a id="spec-trace-070"></a>
### SPEC-TRACE-070 — Version rule
- Adding an optional field: no version change. Consumers must ignore unknown
  fields.
- Removing a field, changing a field's meaning, or changing the encoding: the
  version increases by one.
- A consumer refuses a version it does not implement
  ([REQ-TRACE-004](REQUIREMENTS.md#req-trace-004)). It does not attempt partial
  reading.

<a id="spec-trace-071"></a>
### SPEC-TRACE-071 — The observation format versions independently
[OBSERVATION-SPEC.md](OBSERVATION-SPEC.md) has its own version. The adapter and
the core are shipped together, so the observation version changes more freely.
A recorded observation fixture states its version, and the core supports every
version for which a fixture exists.

<a id="spec-trace-072"></a>
### SPEC-TRACE-072 — Changing this document
A change to this document requires an ADR, a version decision, a fixture at the
new version, and a note in the changelog. See
[QUALITY-GATES.md](QUALITY-GATES.md) §5.
