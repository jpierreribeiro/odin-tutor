# REQUIREMENTS

Every requirement has a stable identifier, a statement, and acceptance criteria.
`SHALL` states an obligation. `SHALL NOT` states a prohibition. `MAY` states a
permitted option.

A requirement without acceptance criteria is not a requirement. Do not add one.

Traceability to specification and test is in [TRACEABILITY.md](TRACEABILITY.md).

---

## 1. Product (`REQ-GEN`)

<a id="req-gen-001"></a>
### REQ-GEN-001 — Local operation
The tool SHALL perform every function without a network connection.

*Acceptance:* every automated test and every documented workflow completes with
outbound network access disabled.

<a id="req-gen-002"></a>
### REQ-GEN-002 — No hidden state outside the working directory
The tool SHALL write only inside a directory that the user can name, and SHALL
report that path.

*Acceptance:* running the tool with a fresh `HOME` and a named work directory
creates files only under that directory.

<a id="req-gen-003"></a>
### REQ-GEN-003 — External tools are declared
The tool SHALL detect each external tool it requires, SHALL report the version it
found, and SHALL fail with a named error when a required tool is absent.

*Acceptance:* with `odin` removed from `PATH`, the tool exits with
`TOOLCHAIN_MISSING` and names `odin`. The same holds for the debugger.

<a id="req-gen-004"></a>
### REQ-GEN-004 — Deterministic trace for a fixed input
Given the same source, the same toolchain versions, and the same configuration,
the tool SHALL produce traces that are equal after excluding the fields that
[TRACE-SPEC.md](TRACE-SPEC.md) §9 lists as non-deterministic.

*Acceptance:* every fixture traced **twice**, and each fixture named in
[SPEC-TEST-050](TEST-STRATEGY.md#spec-test-050) traced **ten times**, produces
byte-identical documents after the documented fields are removed. Address-space
randomisation stays enabled.

*Why not ten times for every fixture:* repetition cost is linear in trace time,
which is the dominant cost of the whole suite. Two runs already vary the address
layout, which is what this check exists to catch. Ten runs are spent on the
fixtures where a non-deterministic traversal order could hide.

<a id="req-gen-005"></a>
### REQ-GEN-005 — The student's source is never modified
The tool SHALL NOT write to, move, or rewrite any file the student authored.

*Acceptance:* a hash of every file under the exercise directory is equal before
and after a full run, including a run that fails.

---

## 2. Compile and execute (`REQ-EXEC`)

<a id="req-exec-001"></a>
### REQ-EXEC-001 — Debug build
The tool SHALL compile the target program with debug information enabled, and
SHALL NOT accept a build configuration supplied by the exercise or the student
that disables it.

*Acceptance:* the compile command recorded in the run report contains the debug
flag. An exercise that tries to override it is rejected with
`EXERCISE_INVALID`.

<a id="req-exec-002"></a>
### REQ-EXEC-002 — Compilation failure is distinct
A compilation failure SHALL produce `PROGRAM_COMPILE_FAILED` and SHALL include
the compiler diagnostics unmodified.

*Acceptance:* a fixture with a type error exits with that class, and the
compiler's own message text appears in the output.

<a id="req-exec-003"></a>
### REQ-EXEC-003 — One execution per trace
The tool SHALL execute the target program at most once to produce one trace.

*Acceptance:* an instrumented fixture that appends to a file on each execution
contains exactly one entry after a full trace and a full navigation session.

<a id="req-exec-004"></a>
### REQ-EXEC-004 — Program exit status is preserved
The trace SHALL record how the target process ended: normal exit with a code, or
termination by a signal with that signal's name.

*Acceptance:* fixtures for exit code 0, exit code 3, and `SIGSEGV` each produce
the matching record.

<a id="req-exec-005"></a>
### REQ-EXEC-005 — Program output is captured separately
The tool SHALL capture the target program's standard output and standard error,
and SHALL NOT mix debugger output into either.

*Acceptance:* a fixture that prints a known string produces exactly that string,
with no debugger text.

<a id="req-exec-006"></a>
### REQ-EXEC-006 — The build cache is keyed by source and toolchain
The tool MAY reuse a previous build. The cache key SHALL include the source
content and the versions of every external tool that affected the build.

*Acceptance:* changing only the compiler version causes a rebuild. A trace
produced by one toolchain is never served for another.

*Rationale:* the correctness of the picture depends on what the compiler
emitted. A cache that ignores the toolchain serves a stale truth after a routine
update. [SPEC-PLAT-030](PLATFORM-SUPPORT.md#spec-plat-030).

<a id="req-exec-007"></a>
### REQ-EXEC-007 — A second thread ends the trace
The tool SHALL detect that the target has more than one thread able to execute
the student's code. On detection it SHALL stop tracing, SHALL produce a valid
trace of the steps recorded so far, and SHALL record the terminal condition
`TARGET_BECAME_MULTITHREADED`.

The tool SHALL NOT record any step observed after that point.

*Acceptance:* the `spawns-thread` fixture produces a trace that ends at the step
before the thread starts, carries the terminal condition, and parses.

*Rationale:* with two threads, memory changes between steps with no line of the
student's code responsible, and the tool cannot attribute the change. Continuing
would draw a believable wrong picture.
[ADR-012](decisions/ADR-012-single-threaded-target.md).

---

## 3. Trace (`REQ-TRACE`)

<a id="req-trace-001"></a>
### REQ-TRACE-001 — Navigation does not re-execute
The tool SHALL navigate between already-generated steps without executing the
target program again.

*Acceptance:* see REQ-EXEC-003. Additionally, navigation works after the target
executable is deleted from disk.

<a id="req-trace-002"></a>
### REQ-TRACE-002 — Backward navigation
The tool SHALL move to any earlier step and SHALL present the same state that it
presented when that step was first reached.

*Acceptance:* for every fixture, stepping to the end and back to step *n*
produces a materialised step equal to the one produced by stepping forward to
*n*.

<a id="req-trace-003"></a>
### REQ-TRACE-003 — Random access
The tool SHALL move directly to any step index.

*Acceptance:* jumping to step *n* produces the same materialised step as
stepping to *n*, for *n* in a set that includes 0, the last step, and a random
sample.

<a id="req-trace-004"></a>
### REQ-TRACE-004 — Versioned format
The trace SHALL carry a format name and an integer version. A consumer SHALL
refuse a version it does not implement, with `TRACE_VERSION_UNSUPPORTED`.

*Acceptance:* a document with an unknown version is refused, and no partial
state is displayed.

<a id="req-trace-005"></a>
### REQ-TRACE-005 — Valid document under every condition
The trace SHALL be a well-formed document even when a budget is reached, when
the target program crashes, and when the adapter fails part way.

*Acceptance:* a fixture for each of those three conditions parses successfully.

<a id="req-trace-006"></a>
### REQ-TRACE-006 — The trace carries no presentation data
The trace SHALL NOT contain screen coordinates, colours, widths, or any other
instruction for a specific user interface.

*Acceptance:* a review checklist item, enforced by a schema that has no such
fields.

<a id="req-trace-007"></a>
### REQ-TRACE-007 — Cumulative output position
Each step SHALL record how much of the program's standard output existed before
that step, counted in a unit that the specification names.

*Acceptance:* a fixture that prints in a loop produces a non-decreasing series
that ends at the true length.

---

## 4. Memory model (`REQ-MEM`)

<a id="req-mem-001"></a>
### REQ-MEM-001 — No raw address as identity
The trace SHALL identify every object and every view by a logical identity. The
trace SHALL NOT use a target memory address as that identity.

*Acceptance:* a schema check rejects an identity field that matches an address
pattern. A fixture traced twice under address randomisation produces equal
identities.

<a id="req-mem-002"></a>
### REQ-MEM-002 — Identity is stable within a run
While an object exists, its logical identity SHALL NOT change between steps.

*Acceptance:* the identity of a named object is equal at its first and last
appearance in every fixture that keeps it alive throughout.

<a id="req-mem-003"></a>
### REQ-MEM-003 — Address reuse does not transfer identity
When the tool observes that the region at an address is no longer the same
region, it SHALL assign a new logical identity.

*Acceptance:* the `free-then-allocate` fixture produces two different
identities. **This requirement is only partly met in version 1. See
[MEMORY-MODEL.md](MEMORY-MODEL.md) §7 and [RISKS.md](RISKS.md) R-07.**

<a id="req-mem-004"></a>
### REQ-MEM-004 — Views with a null data pointer are distinct
Two views whose data pointer is null SHALL have different logical identities
when they occupy different locations.

*Acceptance:* the `two-empty-slices` fixture produces two identities, and the
user interface shows two entries.

<a id="req-mem-005"></a>
### REQ-MEM-005 — Shared storage is represented, not collapsed
Two views that share one storage but differ in offset or length SHALL have
different logical identities, and the trace SHALL record that they share
storage.

*Acceptance:* the `sub-slice` fixture produces two view identities, one shared
storage identity, lengths 3 and 2, and a recorded sharing relation.

<a id="req-mem-006"></a>
### REQ-MEM-006 — Value equality is not identity
Two objects with equal contents and different storage SHALL have different
logical identities.

*Acceptance:* the `two-equal-lists` fixture produces two identities.

<a id="req-mem-007"></a>
### REQ-MEM-007 — Four value states
Each variable in each frame SHALL carry exactly one of `not-yet-active`,
`unreadable`, `unknown`, `valid`. The tool SHALL NOT represent any two of them
by the same output.

*Acceptance:* a fixture produces each state at least once, and the four render
differently.

<a id="req-mem-008"></a>
### REQ-MEM-008 — A frame without readable variables is not a frame without variables
When a frame has variables that are not yet readable, the trace SHALL record
that fact, distinctly from a frame that has no variables.

*Acceptance:* the `prologue` fixture produces a frame marked as having
not-yet-active variables at the entry step, and the user interface does not say
that the procedure has no variables.

<a id="req-mem-009"></a>
### REQ-MEM-009 — Composite types are shown by value
An Odin slice, dynamic array, and string SHALL be presented by their elements or
their text, not by their internal representation. The internal representation
MAY be available on request.

*Acceptance:* the `slice-of-int` fixture shows `[10, 20, 30]`, and does not show
a data pointer in the default view.

<a id="req-mem-010"></a>
### REQ-MEM-010 — Untyped and unshaped pointers are not followed
The tool SHALL NOT read through a pointer whose target type it cannot determine.
This includes `rawptr`, a pointer to a procedure, and a pointer with no debug
type.

*Acceptance:* the `rawptr` fixture records a pointer value and no target object.
An instrumented adapter records zero memory reads through that pointer.

<a id="req-mem-011"></a>
### REQ-MEM-011 — Cycles terminate and are visible
A cyclic object graph SHALL produce a finite trace, and the cycle SHALL be
visible as a reference to an already-present identity.

*Acceptance:* the `cycle` fixture completes, and a field of an object refers to
that object's own identity.

---

## 5. Frames and calls (`REQ-FRAME`)

<a id="req-frame-001"></a>
### REQ-FRAME-001 — Only the student's code produces steps
A step SHALL be recorded only when execution is inside a source file that
belongs to the exercise.

*Acceptance:* a fixture that calls `fmt.println` produces no step inside the
standard library.

<a id="req-frame-002"></a>
### REQ-FRAME-002 — Frame identity is not stack position
The tool SHALL identify a frame by an identity that distinguishes two
invocations that occupy the same stack position at different times.

*Acceptance:* the `two-calls-one-line` fixture produces different frame
identities for the two invocations.

<a id="req-frame-003"></a>
### REQ-FRAME-003 — Return values are attributed or withheld
A recorded return value SHALL belong to the invocation that produced it. When
the tool cannot determine the invocation, it SHALL record `unknown` and SHALL
NOT record a value.

*Acceptance:* the `fibonacci` fixture contains no return value that contradicts
the arguments of its frame. A frame that shows a return value shows the correct
one.

---

## 6. Tracer safety (`REQ-SAFE`)

The target program is untrusted **input to the tracer**. It is not a security
threat to the machine. See [SAFETY.md](SAFETY.md).

<a id="req-safe-001"></a>
### REQ-SAFE-001 — Every read can fail safely
Every read of target memory SHALL have a defined failure path that produces
`unreadable` and continues the trace.

*Acceptance:* the `dangling-pointer` fixture completes and produces `unreadable`
rather than terminating the tool.

<a id="req-safe-002"></a>
### REQ-SAFE-002 — A length from the target is validated before use
A length or count read from the target SHALL be validated against a bound before
it controls any loop or any read size.

*Acceptance:* the `corrupt-length` fixture produces `unknown` for that value, and
an instrumented adapter records no read larger than the bound.

<a id="req-safe-003"></a>
### REQ-SAFE-003 — Enumerated budgets
The tool SHALL enforce a numeric budget for at least: steps, objects per step,
fields per object, elements per collection, string length, pointer traversal
depth, total trace size, and wall-clock time.

*Acceptance:* one fixture per budget reaches that budget and produces the
corresponding truncation record.

<a id="req-safe-004"></a>
### REQ-SAFE-004 — A budget degrades, never corrupts
Reaching a budget SHALL produce a valid trace with a truncation record. It SHALL
NOT produce an invalid document, a partial record, or a fabricated value.

*Acceptance:* every budget fixture from REQ-SAFE-003 produces a document that
parses and carries the truncation record.

<a id="req-safe-005"></a>
### REQ-SAFE-005 — Truncation reaches the user
Every truncation recorded in the trace SHALL be visible in the user interface at
the step where it applies.

*Acceptance:* for each budget fixture, the rendered output contains the
truncation notice.

<a id="req-safe-006"></a>
### REQ-SAFE-006 — The tool survives target termination
Termination of the target process by any signal SHALL produce a trace and a
recorded cause.

*Acceptance:* the `segfault` fixture produces a trace whose last step carries
the termination record.

---

## 7. Terminal user interface (`REQ-TUI`)

<a id="req-tui-001"></a>
### REQ-TUI-001 — Two regions
The interface SHALL present frames and objects as two labelled regions.

*Acceptance:* golden output for the reference fixture matches.

<a id="req-tui-002"></a>
### REQ-TUI-002 — References use stable labels
The interface SHALL present a reference as the logical identity of its target.
It SHALL NOT require drawn arrows.

*Acceptance:* golden output shows the same label at the reference and at the
object.

<a id="req-tui-003"></a>
### REQ-TUI-003 — Navigation commands
The interface SHALL support: next step, previous step, first step, last step,
jump to a step index, and exit.

*Acceptance:* an automated key-sequence test exercises each and asserts the
resulting step index.

<a id="req-tui-004"></a>
### REQ-TUI-004 — Non-interactive rendering
The tool SHALL render any single step as plain text without a terminal, for use
in tests and by assistive technology.

*Acceptance:* `odin-tutor render --step N` writes deterministic text to standard
output with no escape sequences.

<a id="req-tui-005"></a>
### REQ-TUI-005 — Degradation without colour or Unicode
The interface SHALL remain correct and complete when colour is unavailable and
when only ASCII can be shown.

*Acceptance:* golden output in a monochrome ASCII mode carries the same
information as the default mode.

<a id="req-tui-006"></a>
### REQ-TUI-006 — Resize
The interface SHALL redraw correctly after the terminal size changes, and SHALL
NOT lose the current step.

*Acceptance:* a resize test asserts the step index is unchanged and the frame is
redrawn.

<a id="req-tui-007"></a>
### REQ-TUI-007 — The terminal is restored
The interface SHALL restore the terminal to the state it found, on normal exit,
after an error, and after an interrupt signal.

*Acceptance:* a test forces each of the three exits and asserts the terminal
mode and the alternate-screen state are restored.

---

## 8. Exercises (`REQ-EX`)

<a id="req-ex-001"></a>
### REQ-EX-001 — Declarative exercise
An exercise SHALL be a directory that contains metadata, starting source, and
assertions, with no executable configuration.

*Acceptance:* the loader rejects an exercise that contains a script.

<a id="req-ex-002"></a>
### REQ-EX-002 — Assertions are evaluated against the trace
The validator SHALL evaluate assertions against the trace, not against the
source text.

*Acceptance:* a solution that produces the correct picture passes even when its
source differs from the reference solution.

<a id="req-ex-003"></a>
### REQ-EX-003 — Three verdicts
An assertion SHALL evaluate to `pass`, `fail`, or `undetermined`. An exercise
passes only when every assertion is `pass`.

*Acceptance:* a fixture whose trace was truncated before the asserted step
yields `undetermined`, and the exercise does not pass.

<a id="req-ex-004"></a>
### REQ-EX-004 — Failure explains itself
A failing assertion SHALL report the assertion, the step it was evaluated at,
and the observed state.

*Acceptance:* golden output for a known-wrong solution contains all three.

<a id="req-ex-005"></a>
### REQ-EX-005 — Watch mode re-runs on a change
The tool MAY watch the exercise's source and re-run on a change. When it does,
it SHALL complete or abandon a run before starting another, and SHALL NOT
present a trace from one source version beside a verdict from another.

*Acceptance:* a rapid sequence of edits produces a verdict for the last version
only, and no interleaved output.

---

## 9. Platform (`REQ-PLAT`)

<a id="req-plat-001"></a>
### REQ-PLAT-001 — Declared support only
The tool SHALL run its preflight check and SHALL refuse to run with
`UNSUPPORTED_PLATFORM` on a platform combination that
[PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md) does not list as supported.

*Acceptance:* a forced platform string outside the matrix produces that error.

<a id="req-plat-002"></a>
### REQ-PLAT-002 — Toolchain compatibility is checked, not assumed
The tool SHALL compare the detected Odin and debugger versions against the
compatibility matrix, and SHALL warn on an untested combination and fail on a
known-broken one.

*Acceptance:* a stub reporting a known-broken version produces a failure; a stub
reporting an unlisted version produces a warning and continues.

---

## 10. Performance (`REQ-PERF`)

<a id="req-perf-001"></a>
### REQ-PERF-001 — Navigation latency
Moving to any step SHALL complete within the budget in
[PERFORMANCE.md](PERFORMANCE.md) §3.

*Acceptance:* a benchmark over the largest fixture reports the 99th percentile
below the budget.

<a id="req-perf-002"></a>
### REQ-PERF-002 — No super-linear trace assembly
Trace assembly cost SHALL grow linearly in the number of steps.

*Acceptance:* a benchmark at 100, 400, and 1600 steps shows a ratio consistent
with linear growth. **This test exists because a prior system measured a
quadratic size check that made its own step limit unreachable. See
[RISKS.md](RISKS.md) R-09.**

---

## 11. Errors (`REQ-ERR`)

<a id="req-err-001"></a>
### REQ-ERR-001 — Three failure origins are distinct
The tool SHALL distinguish a failure of the target program, a failure of the
tool to observe the target program, and a deliberate omission caused by a
budget.

*Acceptance:* one fixture per origin produces a distinct error class, and no two
map to the same class.

<a id="req-err-002"></a>
### REQ-ERR-002 — Every error is named
Every failure SHALL carry a class from the taxonomy in
[TRACE-SPEC.md](TRACE-SPEC.md) §8. The tool SHALL NOT emit an unclassified
error.

*Acceptance:* a test asserts that every error path in the code maps to a listed
class.
