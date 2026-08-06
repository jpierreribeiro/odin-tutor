# PLATFORM-SUPPORT

Which combinations are supported, and what each unsupported one needs.

**Odin is cross-platform. This tool is not, and will not claim to be.** The
compiler runs everywhere Odin runs. The debug mechanism does not transfer.

---

## 1. Support matrix

| Status | Meaning |
|---|---|
| **Supported** | Tested in continuous integration. Defects are accepted as bugs. |
| **Probing** | Under validation. Not usable. |
| **Planned** | Analysed. Not started. |
| **Not planned** | No analysis. No commitment. |

### Version 1

| OS | Architecture | Debugger | Debug format | Status |
|---|---|---|---|---|
| Linux | x86-64 | GDB | DWARF 4 | **Supported** — probe report committed 2026-08-05 |
| Linux | aarch64 | GDB | DWARF | Planned |
| macOS | aarch64 | LLDB | DWARF | Planned |
| macOS | x86-64 | LLDB | DWARF | Planned |
| Windows | x86-64 | — | PDB | Not planned for version 1; see §4 |
| Windows (WSL2) | x86-64 | GDB | DWARF | Supported by inheritance from Linux, once Linux is Supported |

<a id="spec-plat-001"></a>
### SPEC-PLAT-001 — The tool refuses an unlisted combination
The preflight check compares the detected platform against this matrix. A
combination with status `Planned` or `Not planned` produces
`UNSUPPORTED_PLATFORM` and the tool does not run.

*Rationale:* a tool that half-works on an untested platform produces pictures
nobody has checked. For this tool that is the worst outcome.

---

## 2. Linux

The reference platform.

**Mechanism.** `odin build -debug` emits DWARF. GDB reads it. The adapter runs
inside GDB's Python interpreter.

**Requirements.**

| Requirement | Note |
|---|---|
| `odin` on `PATH` | Version checked against §5 |
| `gdb` with Python support | `gdb --configuration` must report Python |
| `ptrace` permitted | See below |

**`ptrace` and `yama`.** Many distributions set
`kernel.yama.ptrace_scope=1`, which restricts `ptrace` to descendants. The
adapter starts the target itself, so the target *is* a descendant and the
restriction does not apply. The tool does not need `ptrace_scope=0` and must
never ask the user to set it.

<a id="spec-plat-010"></a>
### SPEC-PLAT-010 — The tool never asks for reduced system security
No documentation, error message, or script instructs the user to weaken a
security setting. If a platform requires that, the platform is not supported.

**Containers.** Inside a container, `ptrace` requires the `SYS_PTRACE`
capability, and a masked `/proc` prevents GDB from resolving a
position-independent executable's load base. Running the tool in a container is
not a version 1 use case. If it becomes one, both facts are documented for the
user rather than worked around silently.

---

## 3. macOS

**Status: Planned. Not started.**

**Mechanism.** LLDB, not GDB. LLDB has a Python API of comparable power, so the
adapter's shape transfers. `lldb-mi` is unmaintained and is not a path.

**Obstacles, in order of difficulty.**

1. **Code signing.** Debugging another process on macOS requires the debugger to
   carry the `com.apple.security.cs.debugger` entitlement and to be signed. A
   system LLDB from the Xcode command line tools is signed. A user's own build
   is not. The tool must detect this and produce a clear error rather than a
   confusing permission failure.
2. **A second adapter.** LLDB's Python API differs from GDB's in naming and in
   the value model. This is a port, not a configuration change. Estimated at the
   same order of size as the original adapter.
3. **Debug information.** Odin on macOS emits DWARF, often accompanied by a
   `.dSYM` bundle produced by `dsymutil`. The adapter must locate it. Whether
   the Odin driver produces one automatically is **unverified**.

**Effort estimate:** the largest single portability item in the project.

---

## 4. Windows

**Status: Not planned for version 1.**

Windows is not "the same work with a different debugger". It is a different
debug information format and a different process control API.

| Concern | Linux | Windows (native toolchain) |
|---|---|---|
| Debug format | DWARF | PDB |
| Reader | GDB / DWARF libraries | DIA SDK, or a PDB reader |
| Process control | `ptrace` | Debugging API, `WaitForDebugEvent` |
| Adapter reuse | — | none |

A path exists that avoids all of it: **WSL2**. Inside WSL2 the platform is
Linux, and the Linux adapter applies unchanged. Version 1 documents WSL2 as the
Windows answer.

A native Windows adapter is a separate project. It is not in this repository's
roadmap.

<a id="spec-plat-020"></a>
### SPEC-PLAT-020 — WSL2 is documented, not detected
The tool does not try to detect WSL2 and behave differently. Inside WSL2 it sees
Linux and behaves as on Linux. The documentation tells a Windows user to use
WSL2.

---

## 5. Toolchain compatibility

<a id="spec-plat-030"></a>
### SPEC-PLAT-030 — Versions are checked, not assumed
Preflight detects the Odin version and the debugger version and compares them
against the table below.

| Result | Behaviour |
|---|---|
| Listed as good | Continue. |
| Listed as broken | Fail with `TOOLCHAIN_UNSUPPORTED` and name the reason. |
| Not listed | Warn, record the versions in the run report, continue. |

*Rationale:* the tool's correctness depends on the quality of the debug
information that a specific compiler version emits. That is not a constant.
Community reports describe periods when debugging Odin worked poorly. Treating
the toolchain as a fixed background is how a tool silently starts lying after a
routine update.

### Compatibility table

Every row comes from a probe run that is committed. Do not add a row without
evidence from the probe suite.

| Odin version | Debugger | Platform | Status | Evidence |
|---|---|---|---|---|
| `dev-2026-08:9caff63` (LLVM 18.1.3) | GNU gdb 15.1, with Python | Ubuntu 24.04, x86-64 | **Supported, with one required mitigation** | [`fixtures/toolchain/2026-08-05-linux-x86_64.md`](../fixtures/toolchain/2026-08-05-linux-x86_64.md) |
| `dev-2026-07-nightly:819fdc7` | GNU gdb 15.0.50.20240403-git, with Python | Ubuntu, x86-64 | **Supported, with one required mitigation** | [`fixtures/toolchain/2026-08-05-linux-x86_64-dev-2026-07.md`](../fixtures/toolchain/2026-08-05-linux-x86_64-dev-2026-07.md) |

The second row is the first one produced by [`probes/`](../probes/) rather than
by hand. Both facts recorded under the first row held on it: the entry procedure
resolves as `main::main`, and stepping needed the same mitigation. `frame-key`
reproduced at depth 7 with a stable key, and `finish-breakpoint` attributed all
25 invocations of `fib(6)` with zero wrong values.

Two facts from that run are toolchain-specific and are recorded here because
they will change:

- The entry procedure resolves as **`main::main`**, with a double colon.
  `main.main` does not resolve.
- This version emits **DWARF version 4**, not version 3.

The mitigation in the status column is the stepping confinement in
[DEBUGGER-ADAPTER.md](DEBUGGER-ADAPTER.md) §2.2. Without it, 35% of stops land
outside the student's code.

<a id="spec-plat-031"></a>
### SPEC-PLAT-031 — A row requires evidence
A row is added only when the probe suite
([TEST-STRATEGY.md](TEST-STRATEGY.md) §6) passes on that combination, and the
run report is committed under `fixtures/toolchain/`.

<a id="spec-plat-032"></a>
### SPEC-PLAT-032 — A pinned version for continuous integration
Continuous integration pins one combination. The pinned combination is the one
the project claims to support. The pin is
[`ci/pinned-odin.txt`](../ci/pinned-odin.txt), one release tag, and moving it is
a commit by a person with a probe report behind it
([SPEC-PLAT-031](#spec-plat-031)).

*Rationale:* a pull request must not go red because Odin released something
yesterday. That attributes a toolchain change to whoever happened to push next,
which is both wrong and the fastest way to teach a team to ignore a red mark.

<a id="spec-plat-033"></a>
### SPEC-PLAT-033 — Drift is asked about on a schedule, not on a change
A scheduled job runs the whole suite, every phase gate, and the probe suite
against the **three newest Odin releases**, unpinned. Its failure is the alarm
that [ADR-009](decisions/ADR-009-toolchain-pinning.md) exists to raise: the day
the compiler's debug information stopped supporting the model.

Three releases rather than one, because when the newest breaks something the
next question is always "and the one before it?", and answering that from an
archived run beats bisecting by hand.

Its probe reports are **uploaded, not committed**. A row in the table above
means a person read the report and vouched for it; a job committing rows nightly
would turn evidence back into decoration.

*What this does not do:* it does not add a platform. macOS needs a second
adapter (§3), and a schedule cannot write one. What runs there is §3's honest
subset — everything that does not touch a debugger, plus the assertion that the
tool refuses with a named error rather than crashing.

---

## 6. Architecture dependence

The frame key ([SPEC-MEM-060](MEMORY-MODEL.md#spec-mem-060)) reads a stack
pointer and a program counter. Both exist on every architecture the project
targets, but the register names differ, and the meaning of "the caller's stack
pointer" during a call depends on the calling convention.

<a id="spec-plat-040"></a>
### SPEC-PLAT-040 — The frame key is validated per architecture
The frame key is not assumed to transfer between architectures. Each new
architecture repeats the Phase 0 frame-key probe.

---

## 7. What is never claimed

- The tool does not claim to work on a platform without a row in §1 marked
  Supported.
- A release note never says "cross-platform". It names the supported rows.
- An error on an unsupported platform names the platform and the matrix, so the
  user learns why rather than filing a bug.
