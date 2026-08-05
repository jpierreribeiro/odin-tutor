// Package tutor_obs defines the observation record: what a debugger adapter
// emits, before any interpretation.
//
// The adapter reports what it saw. It assigns no identity, detects no sharing,
// and computes no delta. Those live in package tutor_model, so that they are
// written once and tested without a debugger. See docs/decisions/ADR-003.
package tutor_obs

import "core:encoding/json"

// SCHEMA_VERSION is the observation format version. See SPEC-OBS-001.
SCHEMA_VERSION :: 1

// Value_State is the four-state answer to "what is in this variable?".
// See docs/decisions/ADR-008. `Valid` is the zero value only because JSON
// omits it most often; a missing state must never mean "trustworthy", so
// decoders set it explicitly.
Value_State :: enum {
	Valid,
	Not_Yet_Active,
	Unreadable,
	Unknown,
}

// Kind is what the adapter believes a value is, structurally.
Kind :: enum {
	Scalar,
	String,
	Slice,
	Dynamic_Array,
	Fixed_Array,
	Struct,
	Pointer,
	Map,
	Opaque,
}

// Variable is a named value inside a frame, or a named field inside a struct.
Variable :: struct {
	name:  string `json:"name"`,
	value: Value  `json:"value"`,
}

// Value is one observed value. `state` decides which other fields mean
// anything: when it is not `.Valid`, only `type_name` and `reason` are read.
Value :: struct {
	state:     Value_State  `json:"state"`,
	kind:      Kind         `json:"kind"`,
	type_name: string       `json:"type_name"`,
	// text is the rendered scalar or string content. Empty for composites.
	text:      string       `json:"text,omitempty"`,
	// address of the value itself, used only to derive identity. It never
	// reaches the trace. See SPEC-MEM-001.
	address:   u64          `json:"address,omitempty"`,
	// data and length describe a view: a slice, a string, a dynamic array.
	data:      u64          `json:"data,omitempty"`,
	length:    int          `json:"length,omitempty"`,
	capacity:  int          `json:"capacity,omitempty"`,
	// elem_size is the size of one element, in bytes. The core needs it to
	// decide whether two views overlap, which is how a sub-slice is
	// recognised as a window onto its parent's buffer rather than as an
	// unrelated object. See SPEC-MEM-011.
	elem_size: int          `json:"elem_size,omitempty"`,
	// reason explains a non-Valid state, for the student.
	reason:    string       `json:"reason,omitempty"`,
	// members are a struct's fields, in declaration order. Bounded by the
	// adapter's `fields` budget at the point of the read.
	members:   []Variable   `json:"members,omitempty"`,
}

// Frame is one activation of one procedure.
//
// caller_pc and caller_sp form the frame key (SPEC-MEM-060). They are the
// caller's, not this frame's, because two calls on one source line are two
// call sites and therefore two return addresses. Validated 2026-08-05.
Frame :: struct {
	procedure: string     `json:"procedure"`,
	file:      string     `json:"file"`,
	line:      int        `json:"line"`,
	depth:     int        `json:"depth"`,
	caller_pc: u64        `json:"caller_pc,omitempty"`,
	caller_sp: u64        `json:"caller_sp,omitempty"`,
	variables: []Variable `json:"variables"`,
}

// Returned is a value a procedure gave back, attributed to the invocation
// that produced it by its frame key. When attribution fails, the adapter
// emits nothing rather than guessing. See SPEC-MEM-061.
Returned :: struct {
	caller_pc: u64    `json:"caller_pc"`,
	caller_sp: u64    `json:"caller_sp"`,
	procedure: string `json:"procedure"`,
	value:     Value  `json:"value"`,
}

// Discovered is one object the adapter reached by following a pointer.
//
// It is a flat list per step, not a value nested inside the pointer that found
// it. A cyclic structure cannot be nested — it would recurse forever — so the
// objects are laid out side by side and the pointers refer to them by address.
// The core mints one identity per address, which is how a node that points at
// itself shows its OWN identifier inside itself. See SPEC-MEM-030, REQ-MEM-011.
Discovered :: struct {
	address: u64   `json:"address"`,
	value:   Value `json:"value"`,
}

// Record is one stop of the target program.
Record :: struct {
	index:     int          `json:"index"`,
	file:      string       `json:"file"`,
	line:      int          `json:"line"`,
	frames:    []Frame      `json:"frames"`,
	// objects are what pointer expansion reached at this step, breadth-first
	// and bounded by both expansion budgets. See SPEC-PERF-021.
	objects:   []Discovered `json:"objects,omitempty"`,
	// expansion_truncated says a budget stopped the reading. It is the
	// difference between "the graph ends here" and "we stopped looking".
	// See SPEC-SAFE-030.
	expansion_truncated: bool `json:"expansion_truncated,omitempty"`,
	returned:  []Returned   `json:"returned,omitempty"`,
	// stdout_len is the cumulative byte count of the target's output at this
	// stop. Bytes, not characters: the unit is in the name on purpose.
	// See SPEC-SAFE-031.
	stdout_len: int         `json:"stdout_len"`,
}

// Termination says why the run stopped. Every value here is a fact the
// student can be shown.
Termination :: enum {
	Completed,
	Limit_Steps,
	Limit_Wall_Time,
	Target_Crashed,
	Target_Became_Multithreaded,
	Debug_Info_Missing,
	Adapter_Failed,
}

// Budgets are what the adapter says it enforced. The core cannot verify a
// budget enforced at the read, so it compares this declaration with its own
// configuration and reports a disagreement. See SPEC-SAFE-020 and ADR-006.
Budgets :: struct {
	elements:            int `json:"elements"`,
	fields:              int `json:"fields"`,
	string_length:       int `json:"string_length"`,
	expansions_per_step: int `json:"expansions_per_step"`,
	expansions_total:    int `json:"expansions_total"`,
	sane_length:         int `json:"sane_length"`,
	steps:               int `json:"steps"`,
}

// Stream is one complete adapter output: the whole file, for one run.
Stream :: struct {
	schema_version: int         `json:"schema_version"`,
	adapter:        string      `json:"adapter"`,
	odin_version:   string      `json:"odin_version"`,
	debugger:       string      `json:"debugger"`,
	source_file:    string      `json:"source_file"`,
	budgets:        Budgets     `json:"budgets"`,
	records:        []Record    `json:"records"`,
	termination:    Termination `json:"termination"`,
	// detail carries the named reason when termination is not Completed.
	detail:         string      `json:"detail,omitempty"`,
	stdout:         string      `json:"stdout,omitempty"`,
	exit_code:      int         `json:"exit_code"`,
}

// Decode_Error says why a stream could not be read. It is an enum rather than
// a union because none of these cases carries data the caller can act on
// beyond the name itself. See docs/decisions/ADR-013.
Decode_Error :: enum {
	None,
	Malformed_Json,
	Unsupported_Version,
}

// decode reads an adapter's output.
//
// It refuses an unknown schema version rather than reading what it recognises,
// because a partially understood stream produces a confident wrong picture.
decode :: proc(
	data: []byte,
	allocator := context.allocator,
) -> (
	stream: Stream,
	err: Decode_Error,
) {
	if json.unmarshal(data, &stream, allocator = allocator) != nil {
		return {}, .Malformed_Json
	}
	if stream.schema_version != SCHEMA_VERSION {
		return {}, .Unsupported_Version
	}
	return stream, .None
}

// encode writes a stream. Used by the fixture generator and by tests.
encode :: proc(
	stream: Stream,
	allocator := context.allocator,
) -> (
	data: []byte,
	ok: bool,
) {
	s := stream
	s.schema_version = SCHEMA_VERSION
	bytes, err := json.marshal(s, allocator = allocator)
	return bytes, err == nil
}
