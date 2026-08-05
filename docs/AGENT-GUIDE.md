# AGENT-GUIDE

Rules for any agent, human or otherwise, that changes this repository.

Read this before changing anything. Read [GLOSSARY.md](GLOSSARY.md) second.

---

## 1. Read this first

This project draws pictures of memory. **A wrong picture is worse than no
picture**, because a student learns from it and nothing signals a failure.

Almost every rule below follows from that one fact.

---

## 2. The rules

### Rule 1 — Do not invent requirements
If a behaviour is not specified, and the choice affects architecture, stop and
report the ambiguity. Do not choose silently.

If the choice does not affect architecture, choose, and record the choice in the
change description.

### Rule 2 — Specification precedes implementation
A meaningful feature has a specification first. "Meaningful" means: it changes
the trace, the picture, a verdict, or a platform claim.

A typo fix does not need a specification. A new predicate does.

### Rule 3 — Code does not silently override a specification
When implementation and specification disagree:

```
STOP
REPORT the disagreement
UPDATE the specification, or REQUEST a decision
```

Do not change the contract in the code and leave the document behind. The
document is what the next agent reads.

### Rule 4 — Unknown is better than false
Never fabricate a value, a reference, an identity, a return value, or a frame.
When the information is not available, produce the state that says so.

This applies to the validator too: a missing fact yields `undetermined`, never
`fail`.

### Rule 5 — Every bug becomes a regression test
Especially a bug that produced a plausible wrong picture. The test asserts the
correct picture. A test that only asserts "no error occurred" does not close
such a bug.

Add the fixture to the table in [TEST-STRATEGY.md](TEST-STRATEGY.md) §4.

### Rule 6 — Keep the core deterministic
Given the same source, toolchain, and configuration, the trace is the same.
Identities come from a counter over a deterministic traversal, never from an
address.

Any new source of nondeterminism is documented in
[TRACE-SPEC.md](TRACE-SPEC.md) §9.

### Rule 7 — No premature abstraction
Do not add an interface because it might be needed. An abstraction needs a
documented reason.

Two exist, and both have one:

| Abstraction | Reason |
|---|---|
| The adapter boundary | Three known-different platform mechanisms (GDB, LLDB, native). [ARCHITECTURE.md](ARCHITECTURE.md) §3. |
| Two document formats | Keeps reasoning in the core, makes the adapter replaceable, and makes the core testable without a debugger. [ARCHITECTURE.md](ARCHITECTURE.md) §4. |

A third abstraction needs its own justification, in an ADR.

### Rule 8 — No backend
No server, no database, no hosted runner, no network call.
[ADR-001](decisions/ADR-001-local-first-no-backend.md).

### Rule 9 — No sandbox
The local tool does not sandbox the student's own program. The **tracer** still
defends itself against unsafe memory inspection.
[SAFETY.md](SAFETY.md) §1.

Do not confuse the two. A change that hardens a memory read is correct. A change
that adds process containment is out of scope.

### Rule 10 — External dependencies are explicit
Every dependency carries: purpose, version policy, platform availability,
failure behaviour, licence, and a replacement strategy.

A dependency is not hidden behind a wrapper that makes it look optional when it
is not.

Current dependencies: the Odin compiler, and one debugger. Both are declared in
[PLATFORM-SUPPORT.md](PLATFORM-SUPPORT.md).

### Rule 11 — Use the glossary word
[GLOSSARY.md](GLOSSARY.md) is a controlled vocabulary. Do not introduce a
synonym. If a needed term is missing, add it there first.

The banned-words table at the end of that document is not style advice. "Box"
and "pointer" used loosely are how the model's distinctions get lost.

### Rule 12 — A measurement, not an intuition
A budget, a performance claim, or a "this is fast enough" is backed by a
recorded number. [SPEC-PERF-032](PERFORMANCE.md#spec-perf-032).

---

## 3. Working procedure

### Before changing anything
1. Find the requirement. If none exists, Rule 1.
2. Find the specification. If none exists, Rule 2.
3. Check [RISKS.md](RISKS.md): is this area a known unknown?

### While changing
4. Keep the change inside one component
   ([ARCHITECTURE.md](ARCHITECTURE.md) §2). A change that spans the adapter and
   the model usually means the boundary is being violated.
5. Do not add a field to the trace without updating
   [TRACE-SPEC.md](TRACE-SPEC.md).

### Before declaring it done
6. Work through [QUALITY-GATES.md](QUALITY-GATES.md) for the change type.
7. Update [TRACEABILITY.md](TRACEABILITY.md).
8. Run the anti-lie suite. It is not optional at any milestone.

---

## 4. Writing standard

Documentation follows ASD-STE100 principles where they apply to engineering
prose. See <https://www.asd-ste100.org/>.

ASD-STE100 is a **writing** standard. It does not replace requirements
engineering. Use it for clarity, not as an excuse for vague statements.

| Do | Do not |
|---|---|
| One idea per sentence. | Chain three clauses with semicolons. |
| Active voice: "The core assigns the identity." | "The identity is assigned." |
| The glossary term, every time. | A synonym for variety. |
| A concrete number. | "Fast", "large", "soon". |
| Name the actor. | "It is handled." |
| State the reason after the rule. | Leave a rule with no rationale. |

### The rationale rule
Every non-obvious rule in these documents is followed by *why*. A rule without a
reason gets deleted by the next agent who finds it inconvenient.

### Requirement language
`SHALL` is an obligation. `SHALL NOT` is a prohibition. `MAY` is permission.
Do not write "should" in a requirement.

---

## 5. When you disagree with a specification

That is expected. Specifications are wrong sometimes.

```
1. Say what the specification requires.
2. Say what you believe is right.
3. Say what evidence you have.
4. Propose the ADR.
5. Wait.
```

Do not implement the disagreement first and document it afterwards. The
specification is the shared memory of the project; changing it silently
destroys the only thing that survives a change of maintainer.

---

## 6. Things that look like improvements and are not

| Tempting change | Why not |
|---|---|
| Show the address when the identity is unknown | An address is not an identity and teaches the student to think in addresses. [SPEC-MEM-001](MEMORY-MODEL.md#spec-mem-001). |
| Read `min(length, budget)` elements from a corrupt length | Produces plausible elements from corrupt memory. [SPEC-SAFE-011](SAFETY.md#spec-safe-011). |
| Follow a `rawptr` when the target "looks like" a struct | "Looks like" is a guess. [SPEC-MEM-031](MEMORY-MODEL.md#spec-mem-031). |
| Show the last known value when a read fails | It is not the value now. Use `unreadable`. |
| Merge `unknown` and `not-yet-active`, since both are blank | They mean different things to a student. [SPEC-MEM-020](MEMORY-MODEL.md#spec-mem-020). |
| Make the validator accept `undetermined` as a pass | Blames the tool's limit on the student, in the wrong direction. [SPEC-VAL-001](VALIDATION-SPEC.md#spec-val-001). |
| Cache the trace across a toolchain change | The trace's correctness depends on the toolchain. [SPEC-PLAT-030](PLATFORM-SUPPORT.md#spec-plat-030). |
| Use one visual mark for aliasing and shared storage | Reintroduces the sub-slice bug at the presentation layer. [SPEC-TUI-020](TUI-SPEC.md#spec-tui-020). |
| Speed up the size check by estimating instead of measuring | An estimate in the wrong unit is how a whole trace was lost. [SPEC-SAFE-031](SAFETY.md#spec-safe-031). |

---

## 7. The order of authority

When two documents disagree:

```
1. REQUIREMENTS.md          what must be true
2. the SPEC-* documents     how it is achieved
3. decisions/ADR-*          why it was chosen
4. everything else
```

A disagreement between levels 1 and 2 is a defect in the documents. Report it.
Do not resolve it in code.
