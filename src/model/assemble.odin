package tutor_model

import "core:encoding/json"
import "core:fmt"
import "core:slice"
import "core:strings"
import "base:runtime"
import vmem "core:mem/virtual"
import tutor_obs "../obs"

// Config is what the core enforces, as opposed to what the adapter enforces
// at the read. See SAFETY.md §3 for which budget lives on which side.
Config :: struct {
	objects_per_step:  int,
	trace_bytes:       int,
	keyframe_interval: int,
	// declared_budgets is the core's expectation of what the adapter enforced.
	declared_budgets:  tutor_obs.Budgets,
}

DEFAULT_CONFIG :: Config {
	objects_per_step  = 200,
	trace_bytes       = 32 * 1024 * 1024,
	keyframe_interval = KEYFRAME_INTERVAL,
	declared_budgets  = {
		elements            = 30,
		fields              = 30,
		string_length       = 256,
		expansions_per_step = 32,
		expansions_total    = 600,
		sane_length         = 1_000_000,
		steps               = 2500,
	},
}

// Assembly owns every allocation the trace is made of.
//
// A trace's parts share one lifetime: the frames, the slots, the entities, and
// the steps all die together. That is what an arena is for, so Assembly holds
// one and `assembly_destroy` releases the whole trace in a single call rather
// than walking a tree of slices. See the ownership rule below.
//
// OWNERSHIP: the Trace returned by `assemble` points into this arena. It is
// valid until `assembly_destroy`. A caller that needs the trace to outlive the
// Assembly must encode it first.
//
// Assembly also carries the cost accounting that keeps assembly linear.
//
// THE TRAP: a size check that serialises the accumulated document at every
// step is O(n²). A prior system measured 2.0 s at 533 steps and 46.7 s at 2500,
// inside a 15 s budget. The consequence was not slowness — the step limit
// became unreachable, so every long trace died by timeout inside the measuring
// code, and the student got an error where a truncated trace was correct.
//
// The rule: measure the new step, accumulate the number, never re-measure the
// whole. See SPEC-PERF-020 and ADR-006.
Assembly :: struct {
	arena:       vmem.Arena,
	allocator:   runtime.Allocator,
	registry:    Registry,
	config:      Config,
	// bytes_so_far accumulates. It is never recomputed from the steps.
	bytes_so_far: int,
	truncated:   [dynamic]bool,
	previous:    map[Id]Entity,
	// ranges groups views that sit on one buffer. Rebuilt each step, because
	// an address that is reused is a different storage.
	ranges:      [dynamic]Storage_Range,
	// frame_positions remembers where each invocation was last on screen.
	//
	// A return value is observed AFTER its frame has left the stack, so it can
	// never be attributed to a frame in the record that carries it. It belongs
	// to the invocation that produced it, and that invocation is visible at the
	// steps before it returned. This is how the value gets back to it.
	frame_positions: map[Frame_Key]Frame_Position,
}

// Frame_Key is SPEC-MEM-060's key, whole: the return address in the caller, the
// caller's stack pointer, and the procedure name.
Frame_Key :: struct {
	caller_pc: u64,
	caller_sp: u64,
	procedure: string,
}

Frame_Position :: struct {
	step:  int,
	frame: int,
}

assembly_init :: proc(a: ^Assembly, config := DEFAULT_CONFIG) -> (err: vmem.Allocator_Error) {
	vmem.arena_init_growing(&a.arena) or_return
	a.allocator = vmem.arena_allocator(&a.arena)
	registry_init(&a.registry, a.allocator)
	a.config = config
	a.bytes_so_far = 0
	a.truncated = make([dynamic]bool, a.allocator)
	a.previous = make(map[Id]Entity, a.allocator)
	a.ranges = make([dynamic]Storage_Range, a.allocator)
	a.frame_positions = make(map[Frame_Key]Frame_Position, a.allocator)
	return nil
}

// assembly_destroy releases the arena, and with it the whole trace.
assembly_destroy :: proc(a: ^Assembly) {
	vmem.arena_destroy(&a.arena)
	a^ = {}
}

// step_cost measures one step and nothing else. O(new data), never O(total).
step_cost :: proc(step: Step) -> int {
	bytes, err := json.marshal(step, allocator = context.temp_allocator)
	if err != nil {
		return 0
	}
	// The separator the array will need.
	return len(bytes) + 1
}

// budgets_agree compares what the adapter declared it enforced with what the
// core expected.
//
// The core cannot verify a budget enforced at the read; the declaration is the
// only check available, and an adapter that lies is not detectable. That is
// the accepted price of enforcing read budgets at the read. See ADR-006.
budgets_agree :: proc(declared, expected: tutor_obs.Budgets) -> bool {
	return declared == expected
}

// assemble turns an observation stream into a trace.
//
// It is the one procedure that must stay linear in the number of steps.
assemble :: proc(
	a: ^Assembly,
	stream: tutor_obs.Stream,
) -> (
	trace: Trace,
	err: Build_Error,
) {
	allocator := a.allocator
	if !budgets_agree(stream.budgets, a.config.declared_budgets) {
		return {}, .Budget_Disagreement
	}

	steps := make([dynamic]Step, allocator)
	interval := a.config.keyframe_interval
	if interval < 1 {
		interval = 1
	}

	for record, i in stream.records {
		clear(&a.ranges)
		is_keyframe := (i % interval) == 0
		step := build_step(a, record, i, is_keyframe)
		append(&a.truncated, len(step.truncations) > 0)

		cost := step_cost(step)
		if a.bytes_so_far + cost > a.config.trace_bytes {
			trace = finish(a, stream, steps[:], .Limit_Trace_Bytes)
			return trace, .None
		}
		a.bytes_so_far += cost
		append(&steps, step)
		attribute_returns(a, steps[:], record)
	}

	return finish(a, stream, steps[:], termination_from_obs(stream.termination)), .None
}

finish :: proc(
	a: ^Assembly,
	stream: tutor_obs.Stream,
	steps: []Step,
	termination: Termination,
) -> Trace {
	return Trace {
		trace_version     = TRACE_VERSION,
		source_file       = stream.source_file,
		odin_version      = stream.odin_version,
		debugger          = stream.debugger,
		keyframe_interval = a.config.keyframe_interval,
		steps             = steps,
		termination       = termination,
		detail            = stream.detail,
		stdout            = stream.stdout,
		exit_code         = stream.exit_code,
	}
}

// attribute_returns gives each observed return value back to the invocation
// that produced it.
//
// A return is observed after its frame has left the stack, so it is never
// attributable to a frame in the record that carries it. It is attributed by the
// WHOLE key of SPEC-MEM-060 — return address, caller's stack pointer, procedure
// name — to the last step at which that invocation was on screen.
//
// Attribution is by key and never by firing order. `fib(n-1) + fib(n-2)` puts
// two calls on one source line: the debugger enters and leaves the first without
// stopping at the caller's level, so depth never changes and order says nothing
// about which invocation returned.
//
// A key that does not resolve WITHHOLDS. SPEC-MEM-061: a measured failure from a
// working system had a frame holding n = 0 report that it returned 8, the answer
// for fib(6). A wrong return value teaches that fib(0) is 8. No return value
// teaches nothing, which is better.
attribute_returns :: proc(a: ^Assembly, steps: []Step, record: tutor_obs.Record) {
	for r in record.returned {
		if r.value.state != .Valid {
			continue
		}
		key := Frame_Key{r.caller_pc, r.caller_sp, r.procedure}
		position, found := a.frame_positions[key]
		if !found {
			continue
		}
		if position.step < 0 || position.step >= len(steps) {
			continue
		}
		frames := steps[position.step].frames
		if position.frame < 0 || position.frame >= len(frames) {
			continue
		}
		frames[position.frame].returned_text = r.value.text
		// One invocation returns once. Forgetting the key here means a sibling
		// that reuses the same stack slot cannot inherit this value.
		delete_key(&a.frame_positions, key)
	}
}

// build_step converts one observation record.
build_step :: proc(
	a: ^Assembly,
	record: tutor_obs.Record,
	index: int,
	keyframe: bool,
) -> Step {
	allocator := a.allocator
	frames := make([dynamic]Frame_View, allocator)
	current := make(map[Id]Entity, allocator)
	truncations := make([dynamic]Truncation, allocator)

	// Level 1 of SPEC-MEM-030: every object the adapter reached by following a
	// pointer gets its identity BEFORE any of them is built.
	//
	// Two passes, and the reason is the cycle. A node whose `next` points at
	// itself needs its own identity to already exist when its field is
	// resolved. Minting as we go would leave the first object's self-reference
	// unresolvable, and "unresolvable" would render as a pointer into nothing —
	// which is how a cycle gets drawn as a dead end.
	// A death the program reported, before any identity is minted for this step.
	// Positive evidence, and it needs no guard: ADR-011's caution is about
	// ABSENCE, and this is not absence.
	for address in record.freed {
		advance_epoch_on_free(&a.registry, address)
	}

	discovered := make(map[u64]Id, allocator)
	for object in record.objects {
		if object.address == 0 {
			continue
		}
		address := object.address
		type_name := object.value.type_name

		// The epoch is decided BEFORE the identity is minted, because it is part
		// of the key. Both rules of SPEC-MEM-041 apply here and nowhere else.
		//
		// Rule 1: a different type at one address is positive evidence that the
		// bytes are a different thing now.
		if previous, found := a.registry.last_type[address]; found && previous != type_name {
			advance_epoch_on_type_change(&a.registry, address, previous, type_name)
		}
		// Rule 2, with ADR-011's guard: absence counts as evidence of death only
		// when every step it was absent for was observed COMPLETELY. A budget
		// hid it is not the same fact as it died. `a.truncated` holds one entry
		// per step already built, which is exactly the window to inspect.
		advance_epoch_on_absence(&a.registry, address, type_name, index, a.truncated[:])
		a.registry.last_type[address] = type_name

		discovered[address] = identity_for(&a.registry, Key{
			kind      = .Object,
			address   = address,
			type_name = type_name,
			epoch     = epoch_for(&a.registry, address, type_name),
		})
	}

	for object in record.objects {
		id, found := discovered[object.address]
		if !found {
			continue
		}
		if len(current) >= a.config.objects_per_step {
			if len(truncations) == 0 {
				append(&truncations, Truncation{"objects", a.config.objects_per_step})
			}
			break
		}
		entity := Entity {
			id        = id,
			kind      = .Object,
			type_name = object.value.type_name,
			text      = object.value.text,
			length    = object.value.length,
		}
		members := make([dynamic]Slot, allocator)
		for member in object.value.members {
			append(&members, slot_from_value(a, member, discovered, &current, &truncations))
		}
		entity.members = members[:]
		current[id] = entity
		note_seen(&a.registry, object.address, object.value.type_name, index)
	}

	if record.expansion_truncated && len(truncations) == 0 {
		// A budget stopped the reading, not the graph. Saying so is what keeps
		// "the object ends here" apart from "we stopped looking".
		// See SPEC-SAFE-030, ADR-011.
		append(&truncations, Truncation{"expansions", a.config.declared_budgets.expansions_per_step})
	}

	for frame in record.frames {
		key := Key {
			kind      = .Object,
			address   = frame.caller_sp,
			location  = frame.caller_pc,
			type_name = frame.procedure,
		}
		frame_id := identity_for(&a.registry, key)

		slots := make([dynamic]Slot, allocator)
		for variable in frame.variables {
			slot := slot_from_value(a, variable, discovered, &current, &truncations)
			if slot.state == .Valid && variable.value.data != 0 {
				note_seen(&a.registry, variable.value.data, variable.value.type_name, index)
			}
			append(&slots, slot)
		}

		view := Frame_View {
			id        = frame_id,
			procedure = frame.procedure,
			line      = frame.line,
			depth     = frame.depth,
			slots     = slots[:],
		}
		// Where this invocation is on screen, so a return value observed later
		// can find it. Overwritten each time the frame is seen, which is what
		// makes it the LAST step before the return.
		a.frame_positions[Frame_Key{frame.caller_pc, frame.caller_sp, frame.procedure}] =
			Frame_Position{step = index, frame = len(frames)}
		append(&frames, view)
	}

	mark_only_real_sharing(&current)

	entities, removed := diff(a, current, keyframe)

	return Step {
		index       = index,
		file        = record.file,
		line        = record.line,
		keyframe    = keyframe,
		frames      = frames[:],
		entities    = entities,
		removed     = removed,
		stdout_len  = record.stdout_len,
		truncations = truncations[:],
	}
}

// slot_from_value turns one observed variable or field into a slot.
//
// The pointer branch is the whole point. A pointer whose target the adapter
// reached becomes a REFERENCE to that object's identity — a label, never an
// address (ADR-007, SPEC-MEM-001). A pointer whose target it did not reach
// keeps its own text and refers to nothing, which is what SPEC-MEM-031 requires
// for a rawptr, a procedure pointer, a pointer to a scalar, and a pointer whose
// target type the debug information does not describe.
//
// The difference matters more than it looks. "refers to #4" is a fact. An
// address printed where a reference belongs teaches the student to think in
// addresses, which is the habit this tool exists to replace.
slot_from_value :: proc(
	a: ^Assembly,
	variable: tutor_obs.Variable,
	discovered: map[u64]Id,
	current: ^map[Id]Entity,
	truncations: ^[dynamic]Truncation,
) -> Slot {
	slot := Slot {
		name   = variable.name,
		state  = state_from_obs(variable.value.state),
		reason = variable.value.reason,
	}
	if slot.state != .Valid {
		return slot
	}

	#partial switch variable.value.kind {
	case .Scalar:
		slot.text = variable.value.text
	case .Pointer:
		if variable.value.data != 0 {
			if target, found := discovered[variable.value.data]; found {
				slot.refers_to = target
				return slot
			}
		}
		// Not followed, or followed and not reachable. Say so with the
		// pointer's own text rather than inventing a target.
		slot.text = variable.value.text
	case:
		entity, id := entity_from_value(a, variable.value, discovered, current, truncations)
		slot.refers_to = id
		if len(current) < a.config.objects_per_step {
			current[id] = entity
		} else if len(truncations) == 0 {
			append(truncations, Truncation{"objects", a.config.objects_per_step})
		}
	}
	return slot
}

// mark_only_real_sharing clears the sharing mark on a view that is alone.
//
// `storage_for` names the storage every view sits on, because grouping by
// overlap is how a sub-slice is recognised as a window onto its parent's buffer.
// But sitting on a storage is not sharing it. A view that is the only one there
// shares with nobody, and `shares_storage_with` is documented as naming the
// storage "when it shares".
//
// Without this, every slice in the program carries a sharing mark, including two
// lists with entirely separate buffers. The student reads "shares storage" and
// learns a relationship that does not exist — the plausible-but-false picture
// this project exists to prevent (ADR-008, SPEC-TUI-020).
//
// Sharing is decided here, in the model, and not in the renderer: the renderer
// must not differ from the interface in content, so a fact only one of them
// computes is a fact they can disagree about (ARCHITECTURE.md §2).
mark_only_real_sharing :: proc(current: ^map[Id]Entity) {
	occupants: map[Id]int
	defer delete(occupants)

	for _, entity in current {
		if entity.shares_storage_with != NO_ID {
			occupants[entity.shares_storage_with] += 1
		}
	}
	for id, &entity in current {
		if entity.shares_storage_with != NO_ID && occupants[entity.shares_storage_with] < 2 {
			entity.shares_storage_with = NO_ID
		}
		_ = id
	}
}

// entity_from_value builds one entity and returns its identity.
entity_from_value :: proc(
	a: ^Assembly,
	value: tutor_obs.Value,
	discovered: map[u64]Id,
	current: ^map[Id]Entity,
	truncations: ^[dynamic]Truncation,
) -> (
	entity: Entity,
	id: Id,
) {
	kind: Entity_Kind = .Object
	#partial switch value.kind {
	case .Slice, .String, .Dynamic_Array:
		kind = .View
	}

	key := Key {
		kind      = kind,
		address   = value.data,
		location  = value.address,
		length    = value.length,
		type_name = value.type_name,
		epoch     = epoch_for(&a.registry, value.data, value.type_name),
	}
	id = identity_for(&a.registry, key)

	entity = Entity {
		id        = id,
		kind      = kind,
		type_name = value.type_name,
		text      = value.text,
		length    = value.length,
	}
	// A view's elements, which the adapter read bounded by the `elements` budget
	// and only after the length passed validation. They are members of the view
	// rather than objects of their own: an element is a position inside one
	// storage, not a separate thing that could be shared.
	if len(value.members) > 0 {
		members := make([dynamic]Slot, a.allocator)
		for member in value.members {
			append(&members, slot_from_value(a, member, discovered, current, truncations))
		}
		entity.members = members[:]
	}
	if kind == .View && value.data != 0 {
		// Two views over one buffer share a visible thing rather than being
		// collapsed into one. Grouping is by overlap, not by pointer equality:
		// a sub-slice starts further along the same buffer. See SPEC-MEM-005.
		entity.shares_storage_with = storage_for(
			&a.ranges, &a.registry,
			value.data, value.length, value.elem_size, value.type_name, key.epoch,
		)
	}
	return entity, id
}

// diff produces the entity list for a step: everything at a keyframe, only
// what changed at a delta.
//
// A changed entity is emitted whole. Whole-entity replacement makes
// materialisation trivially correct and a delta readable; the size saving of
// field-level deltas is not worth the class of bug it invites.
// See SPEC-TRACE-003.
diff :: proc(
	a: ^Assembly,
	current: map[Id]Entity,
	keyframe: bool,
) -> (
	entities: []Entity,
	removed: []Id,
) {
	out := make([dynamic]Entity, a.allocator)
	gone := make([dynamic]Id, a.allocator)

	if keyframe {
		for _, e in current {
			append(&out, e)
		}
	} else {
		for id, e in current {
			old, existed := a.previous[id]
			if !existed || !entity_equal(old, e) {
				append(&out, e)
			}
		}
		for id in a.previous {
			if _, still := current[id]; !still {
				append(&gone, id)
			}
		}
	}

	clear(&a.previous)
	for id, e in current {
		a.previous[id] = e
	}

	slice.sort_by(out[:], proc(x, y: Entity) -> bool { return x.id < y.id })
	slice.sort(gone[:])
	return out[:], gone[:]
}

entity_equal :: proc(x, y: Entity) -> bool {
	if x.id != y.id || x.kind != y.kind || x.type_name != y.type_name {
		return false
	}
	if x.text != y.text || x.length != y.length {
		return false
	}
	if x.shares_storage_with != y.shares_storage_with {
		return false
	}
	if len(x.members) != len(y.members) {
		return false
	}
	for m, i in x.members {
		if m != y.members[i] {
			return false
		}
	}
	return true
}

// describe_termination gives the student a sentence, not an enum name.
describe_termination :: proc(t: Trace, allocator := context.allocator) -> string {
	switch t.termination {
	case .Completed:
		return strings.clone("The program ran to completion.", allocator)
	case .Limit_Steps:
		return strings.clone("The step limit was reached. The trace is complete up to that step.", allocator)
	case .Limit_Wall_Time:
		return strings.clone("The time limit was reached. The trace is complete up to that step.", allocator)
	case .Limit_Trace_Bytes:
		return strings.clone("The trace size limit was reached. The trace is complete up to that step.", allocator)
	case .Target_Crashed:
		return fmt.aprintf("The program stopped: %s", t.detail, allocator = allocator)
	case .Target_Became_Multithreaded:
		return strings.clone(
			"The program started a second thread. Tracing stopped there, because memory can then change with no line of your code responsible.",
			allocator,
		)
	case .Debug_Info_Missing:
		return strings.clone("The program was built without debug information.", allocator)
	case .Adapter_Failed:
		return fmt.aprintf("The tracer failed: %s", t.detail, allocator = allocator)
	}
	return strings.clone("Unknown.", allocator)
}
