package tutor_model

import "core:encoding/json"
import "core:slice"
import tutor_obs "../obs"

// TRACE_VERSION is the trace format version. A consumer that does not know
// this number refuses the document rather than reading what it recognises.
// See SPEC-TRACE-070.
TRACE_VERSION :: 1

// KEYFRAME_INTERVAL is `K` from ADR-005. A keyframe at least every K steps
// bounds both a jump (at most K-1 deltas) and the damage a bad delta can do
// (at most one interval). K = 1 yields full snapshots and is a supported
// debugging mode.
KEYFRAME_INTERVAL :: 32

// Value_State mirrors the observation's four states. It is re-declared rather
// than aliased so that the trace format can version independently of the
// observation format. See ADR-003.
Value_State :: enum {
	Valid,
	Not_Yet_Active,
	Unreadable,
	Unknown,
}

// Slot is one named value in a frame, after identity assignment.
Slot :: struct {
	name:   string      `json:"name"`,
	state:  Value_State `json:"state"`,
	// text is the shown content, for a scalar or a string.
	text:   string      `json:"text,omitempty"`,
	// length is the element count when one was observed, even if the contents
	// were not. A map is the case this exists for: ADR-014 says it is COUNTED,
	// not walked, so the count is real while the entries are `unknown`.
	length: int         `json:"length,omitempty"`,
	// type_name is the type AS DECLARED, so `distinct` survives to the screen.
	// An entity carries its own; a scalar has no entity and would otherwise
	// have nowhere to put it. Optional, so no format version change
	// (SPEC-TRACE-070).
	type_name: string   `json:"type_name,omitempty"`,
	// refers_to is the identity of the entity this slot points at, or 0.
	// The interface prints it as a label. It is never an address.
	refers_to: Id       `json:"refers_to,omitempty"`,
	// is_reference separates a POINTER from the object itself. Both reach an
	// entity, and an exercise that asks for an allocation rather than a local
	// has no other way to say so. See SPEC-VAL-024.
	is_reference: bool  `json:"is_reference,omitempty"`,
	reason:    string   `json:"reason,omitempty"`,
}

// Frame_View is one activation, as the trace records it.
Frame_View :: struct {
	id:        Id     `json:"id"`,
	procedure: string `json:"procedure"`,
	line:      int    `json:"line"`,
	depth:     int    `json:"depth"`,
	slots:     []Slot `json:"slots"`,
	// returned_text is shown only when the value was attributed to this exact
	// invocation. When attribution fails the field stays empty: withholding is
	// allowed, lying is not. See SPEC-MEM-061.
	returned_text: string `json:"returned_text,omitempty"`,
}

// Entity is one object, view, or storage in the picture.
Entity :: struct {
	id:        Id     `json:"id"`,
	kind:      Entity_Kind `json:"kind"`,
	type_name: string `json:"type_name"`,
	// text for a scalar or string; empty for a composite.
	text:      string `json:"text,omitempty"`,
	// members are the fields or elements, in declaration or index order.
	members:   []Slot `json:"members,omitempty"`,
	// shares_storage_with names the storage this view sits on, when it shares
	// one. Aliasing and shared storage are different relations and get
	// different marks on screen. See SPEC-TUI-020.
	shares_storage_with: Id `json:"shares_storage_with,omitempty"`,
	length: int `json:"length,omitempty"`,
}

// Truncation records that a budget was reached, at the step where it was.
// Every limit is visible to the student. See REQ-SAFE-005.
Truncation :: struct {
	what:  string `json:"what"`,
	limit: int    `json:"limit"`,
}

// Step is one line of the student's program, executed.
Step :: struct {
	index:    int          `json:"index"`,
	file:     string       `json:"file"`,
	line:     int          `json:"line"`,
	// keyframe says whether `entities` is complete or a delta.
	keyframe: bool         `json:"keyframe"`,
	frames:   []Frame_View `json:"frames"`,
	// entities holds every entity at a keyframe, or only those that changed
	// at a delta. A changed entity is emitted whole. See SPEC-TRACE-003.
	entities: []Entity     `json:"entities"`,
	// removed names entities that left the picture, at a delta only.
	removed:  []Id         `json:"removed,omitempty"`,
	// died names the identities the program RETURNED TO THE ALLOCATOR at this
	// step. It is the one piece of positive evidence of death this model has:
	// `removed` means "no longer reachable", which ADR-011 says is not evidence
	// of anything, and `died` means "the program said so".
	died:     []Id         `json:"died,omitempty"`,
	stdout_len: int        `json:"stdout_len"`,
	truncations: []Truncation `json:"truncations,omitempty"`,
}

// Termination mirrors the observation's, plus what the core itself can decide.
Termination :: enum {
	Completed,
	Limit_Steps,
	Limit_Wall_Time,
	Limit_Trace_Bytes,
	Target_Crashed,
	Target_Became_Multithreaded,
	Debug_Info_Missing,
	Adapter_Failed,
}

// Trace is the whole artefact. Navigation reads it and never re-executes.
// See SPEC-PERF-001, REQ-TRACE-001.
Trace :: struct {
	trace_version:     int         `json:"trace_version"`,
	source_file:       string      `json:"source_file"`,
	odin_version:      string      `json:"odin_version"`,
	debugger:          string      `json:"debugger"`,
	keyframe_interval: int         `json:"keyframe_interval"`,
	steps:             []Step      `json:"steps"`,
	termination:       Termination `json:"termination"`,
	detail:            string      `json:"detail,omitempty"`,
	stdout:            string      `json:"stdout,omitempty"`,
	exit_code:         int         `json:"exit_code"`,
}

// Build_Error says why a trace could not be assembled.
Build_Error :: enum {
	None,
	Budget_Disagreement,
}

// state_from_obs maps an observation state onto a trace state.
//
// The two enums are separate on purpose (ADR-003), so this mapping is the one
// place a change in either is felt.
state_from_obs :: proc(s: tutor_obs.Value_State) -> Value_State {
	switch s {
	case .Valid:          return .Valid
	case .Not_Yet_Active: return .Not_Yet_Active
	case .Unreadable:     return .Unreadable
	case .Unknown:        return .Unknown
	}
	return .Unknown
}

termination_from_obs :: proc(t: tutor_obs.Termination) -> Termination {
	switch t {
	case .Completed:                   return .Completed
	case .Limit_Steps:                 return .Limit_Steps
	case .Limit_Wall_Time:             return .Limit_Wall_Time
	case .Target_Crashed:              return .Target_Crashed
	case .Target_Became_Multithreaded: return .Target_Became_Multithreaded
	case .Debug_Info_Missing:          return .Debug_Info_Missing
	case .Adapter_Failed:              return .Adapter_Failed
	}
	return .Adapter_Failed
}

// encode writes the trace. The caller measures the result against the byte
// budget; an incremental estimate is a cheap early stop, never the guarantee.
// See SPEC-SAFE-032.
encode :: proc(t: Trace, allocator := context.allocator) -> (data: []byte, ok: bool) {
	out := t
	out.trace_version = TRACE_VERSION
	bytes, err := json.marshal(out, allocator = allocator)
	return bytes, err == nil
}

// decode reads a trace, refusing an unknown version.
decode :: proc(data: []byte, allocator := context.allocator) -> (t: Trace, ok: bool) {
	if json.unmarshal(data, &t, allocator = allocator) != nil {
		return {}, false
	}
	return t, t.trace_version == TRACE_VERSION
}

// materialise returns the complete entity set at `index`.
//
// It takes the greatest keyframe at or before `index` and applies the deltas
// after it, in order. It never replays from step 0. See SPEC-TRACE-002 and
// SPEC-PERF-022.
materialise :: proc(
	t: Trace,
	index: int,
	allocator := context.allocator,
) -> (
	entities: []Entity,
	ok: bool,
) {
	if index < 0 || index >= len(t.steps) {
		return nil, false
	}
	start := index
	for start > 0 && !t.steps[start].keyframe {
		start -= 1
	}
	if !t.steps[start].keyframe {
		return nil, false
	}

	live := make(map[Id]Entity, allocator)
	defer delete(live)

	for i in start ..= index {
		step := t.steps[i]
		for id in step.removed {
			delete_key(&live, id)
		}
		for e in step.entities {
			live[e.id] = e
		}
	}

	out := make([dynamic]Entity, 0, len(live), allocator)
	for _, e in live {
		append(&out, e)
	}
	// Deterministic order. A map iterates arbitrarily, and an arbitrary order
	// would make two runs of one fixture differ. See SPEC-TEST-050.
	slice.sort_by(out[:], proc(a, b: Entity) -> bool { return a.id < b.id })
	return out[:], true
}
