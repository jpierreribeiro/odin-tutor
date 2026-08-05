# ARCHITECTURE

How the parts are arranged, and which language each part is written in.

---

## 1. Shape

```
  exercise / .odin file
          |
          v
  +-------------------+      odin build -debug        +------------------+
  |  Build            | ----------------------------> | external: odin   |
  +-------------------+                               +------------------+
          |  debuggable executable
          v
  +-------------------+      drives, over a pipe      +------------------+
  |  Adapter          | <---------------------------> | external: gdb    |
  +-------------------+                               +------------------+
          |  observation records  (raw, addresses, no identity)
          v
  +-------------------+
  |  Core: model      |   assigns identity, detects sharing, encodes trace
  +-------------------+
          |  trace  (semantic, versioned, no addresses as identity)
          v
     +----+-----+-----------+
     |          |           |
     v          v           v
  +------+  +--------+  +-----------+
  | TUI  |  | render |  | validator |
  +------+  +--------+  +-----------+
```

Everything below the adapter is written in Odin. The adapter is the only place
where another language appears, and it is bounded by a documented contract.

---

## 2. Component responsibilities

| Component | Responsibility | Must not |
|---|---|---|
| **CLI** | Parse arguments. Select mode. Report errors. | Contain model logic. |
| **Preflight** | Detect `odin` and the debugger. Check versions against the matrix. | Continue silently on an unknown version. |
| **Build** | Run the compiler with debug information. Capture diagnostics. | Accept a build flag from an exercise. |
| **Adapter** | Drive the debugger. Read target state. Enforce read-time budgets. Emit observation records. | Assign logical identity. Encode deltas. Decide presentation. |
| **Model** | Assign identity. Resolve pointers to references. Detect shared storage. Apply per-trace budgets. Produce the trace. | Read target memory. Know about terminals. |
| **Store** | Serialise and load the trace. Materialise a step from keyframes and deltas. | Change semantics. |
| **TUI** | Present one materialised step. Handle input. | Compute identity. Re-execute anything. |
| **Render** | Produce plain text for one step. | Differ from the TUI in content. |
| **Validator** | Evaluate assertions against the trace. | Read the source text. |
| **Exercise engine** | Discover, order, and report exercises. | Contain per-exercise logic in code. |

---

## 3. The language question

The project asked whether the tool can be written entirely in Odin. The honest
answer has three parts.

### 3.1 What is written in Odin

All of it, except extraction.

- CLI, preflight, build orchestration
- The whole memory and identity model
- Trace encoding, storage, materialisation
- The terminal user interface and the plain renderer
- The exercise engine and the validator
- The test harness, using `odin test`

This is the large majority of the code and all of the parts that carry the
project's reasoning.

### 3.2 What requires an external process

- **The Odin compiler.** Required. It is not replaceable.
- **A debugger.** Required in version 1. See §3.3 for why.

### 3.3 What cannot be Odin in version 1, and why

To read a stopped process's stack frames and typed locals, something must:

1. control the process (`ptrace` on Linux);
2. parse the executable's debug information (DWARF);
3. evaluate DWARF location expressions to find where a variable lives;
4. read that memory.

All four are possible in Odin on Linux. None is small. Item 2 alone — a DWARF
reader covering compile units, subprograms, variables, base and struct and
pointer and array types, the line table, and the location expressions Odin
emits — is a project in its own right.

Version 1 therefore uses a debugger, and the adapter is the component that talks
to it.

Two ways exist to talk to GDB.

| Approach | Language of our code | Cost |
|---|---|---|
| **GDB/MI over a pipe** | 100% Odin | Every value arrives as text and must be re-parsed. Every read is a round trip. Read-time budgets are hard to enforce because the read has already happened when we see the answer. |
| **A script inside GDB's embedded Python** | Odin plus a bounded Python shim | Direct access to typed values. Budgets enforced at the point of the read. One document out per run. |

Version 1 uses the second. The reason is not convenience: it is
[REQ-SAFE-002](REQUIREMENTS.md#req-safe-002). A length read from a corrupt
target must be validated *before* it controls a read size, and that check must
sit where the read happens. See
[ADR-004](decisions/ADR-004-in-debugger-extractor.md).

### 3.4 The dependency buckets

| Bucket | Contents |
|---|---|
| **Core written in Odin** | CLI, preflight, build, model, identity, trace store, materialisation, TUI, renderer, exercise engine, validator, tests |
| **External required tool** | `odin` (compiler); `gdb` (debugger, Linux) |
| **Bounded non-Odin component** | The in-debugger extractor script. Replaceable behind [SPEC-OBS](OBSERVATION-SPEC.md). |
| **Optional platform integration** | None in version 1 |
| **Future portability concern** | macOS (LLDB adapter, code signing); Windows (PDB, different debug API); non-x86-64 architectures; a native Odin adapter that removes the debugger |

### 3.5 The path to fewer external parts

The adapter boundary is defined so that a future native adapter can replace the
current one without changing anything above it. That adapter would be Odin,
Linux-only, and would need `ptrace` plus a DWARF reader. It is
[ROADMAP.md](ROADMAP.md) Phase 7 and it is explicitly optional. The project does
not depend on it.

---

## 4. Why two document formats

The adapter emits **observation records**. The core emits a **trace**. These are
different formats. This is a deliberate cost.

Three reasons justify it.

1. **It keeps reasoning in Odin.** If the adapter emitted the final trace, then
   identity, sharing detection, and delta encoding would live in the extractor
   script. Those are the parts most likely to contain a subtle error, and they
   are the parts this project most wants to own and test.
2. **It makes the adapter replaceable.** A second adapter (LLDB, or native)
   implements one small contract instead of the whole model.
3. **It makes the core testable without a debugger.** Recorded observation
   records are fixtures. Most of the model's tests need no `gdb`, no `odin`, and
   no target process. See [TEST-STRATEGY.md](TEST-STRATEGY.md) §3.

Reason 3 is the strongest. It converts a category of test that would otherwise
be a slow, environment-dependent integration test into a fast, deterministic
unit test.

The cost is two schemas to version. [TRACE-SPEC.md](TRACE-SPEC.md) §10 states
the evolution rule for both.

---

## 5. Data flow, in order

1. **Preflight.** Detect tools. Check the compatibility matrix. Fail or warn.
2. **Build.** Compile with debug information into a work directory. On failure,
   stop with `PROGRAM_COMPILE_FAILED`.
3. **Observe.** Start the adapter. The adapter starts the debugger, sets a
   breakpoint on the student's entry procedure, and steps. At each step inside
   the student's file, it reads the frames and the reachable values under
   read-time budgets, and appends one observation record. It captures the target
   program's own output to separate files.
4. **Model.** Read observation records in order. Assign identity. Resolve
   pointers. Detect shared storage. Apply per-trace budgets. Emit the trace.
5. **Store.** Serialise the trace as keyframes and deltas.
6. **Consume.** The TUI, the renderer, and the validator each read the trace and
   materialise the steps they need.

Steps 3 and 4 are separate passes over a stream, not one fused loop. That
separation is what makes step 4 testable in isolation.

---

## 6. Process and file layout at run time

```
<work-dir>/
  build/
    main                  the debuggable executable
    compile.log           compiler diagnostics
  run/
    stdout.txt            the target program's standard output
    stderr.txt            the target program's standard error
    observations.jsonl    one observation record per line
  trace/
    trace.json            the trace document
  report.json             run outcome, versions, budgets reached
```

`observations.jsonl` is line-delimited on purpose: the adapter can append while
running, and a truncated final line is detectable and discardable without losing
what came before.

---

## 5. Repository layout

As built. Every package name is `tutor_*` because the package name is the
linker's prefix and must be unique across the program, while the folder name is
what an importer sees. See [ADR-013](decisions/ADR-013-odin-conventions.md) §3.

```
src/
  obs/         tutor_obs        the observation record: what the adapter saw
  model/       tutor_model      identity, epochs, assembly, delta encoding
  render/      tutor_render     a step as text; labels, never arrows
  preflight/   tutor_preflight  toolchain detection and the compatibility check
  tutor/       tutor_cli        the entry point; wires the others, owns no logic
adapter/
  gdb_extractor.py              the one non-Odin component; runs inside GDB
schemas/
  observation-v1.schema.json    the adapter's output contract
  trace-v1.schema.json          the consumer's input contract
fixtures/
  toolchain/                    probe scripts and committed probe reports
  observations/                 recorded streams: the primary test input
docs/
```

Dependencies run one way. Odin forbids a cycle between packages, so the order
is enforced by the compiler rather than by discipline:

```
obs  ←  model  ←  render
             ↖    ↖
               tutor  →  preflight
```

`obs` depends on nothing but `core:`. That is what lets a recorded observation
stream drive the model, the renderer, and the validator with no debugger
present — the strongest reason for two formats
([ADR-003](decisions/ADR-003-two-document-formats.md)).


## 8. What this architecture refuses

- **No server.** [ADR-001](decisions/ADR-001-local-first-no-backend.md).
- **No sandbox.** [ADR-001](decisions/ADR-001-local-first-no-backend.md) and
  [SAFETY.md](SAFETY.md).
- **No plugin system.** There is one adapter interface, with a reason. There is
  no general extension mechanism.
- **No abstraction over the compiler.** The tool runs `odin`. It does not model
  "a build system".
- **No graph layout engine.** The interface uses labels.
  [ADR-007](decisions/ADR-007-labels-not-arrows.md).
