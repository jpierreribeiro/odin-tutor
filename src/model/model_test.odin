package tutor_model

import "core:testing"
import tutor_obs "../obs"

// Helpers ---------------------------------------------------------------

scalar :: proc(text: string) -> tutor_obs.Value {
	return {state = .Valid, kind = .Scalar, type_name = "int", text = text}
}

view :: proc(data: u64, length: int, location: u64, type_name := "[]int") -> tutor_obs.Value {
	return {
		state = .Valid, kind = .Slice, type_name = type_name,
		data = data, length = length, address = location,
	}
}

one_frame :: proc(vars: []tutor_obs.Variable, pc: u64 = 0x100, sp: u64 = 0x200) -> tutor_obs.Frame {
	return {procedure = "main", file = "m.odin", line = 1, caller_pc = pc, caller_sp = sp, variables = vars}
}

stream_of :: proc(records: []tutor_obs.Record) -> tutor_obs.Stream {
	return {
		schema_version = tutor_obs.SCHEMA_VERSION,
		source_file = "m.odin",
		budgets = DEFAULT_CONFIG.declared_budgets,
		records = records,
		termination = .Completed,
	}
}

// Identity --------------------------------------------------------------

@(test)
identity_is_never_an_address :: proc(t: ^testing.T) {
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	id := identity_for(&r, Key{kind = .Object, address = 0x7fff_dead_beef})
	// A dense counter starting at 1. Anything resembling the address would
	// make the trace non-deterministic under address randomisation.
	testing.expect_value(t, id, Id(1))
	testing.expect(t, int(id) < 1000, "identity must be a small counter, not an address")
}

@(test)
two_empty_views_are_distinct :: proc(t: ^testing.T) {
	// Measured 2026-08-05: two empty slices are byte-identical, both
	// {data: 0x0, len: 0}. Only the holder's location separates them.
	// A key without `location` collapses every empty slice into one object.
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	a := identity_for(&r, Key{kind = .View, address = 0, location = 0xAAA, length = 0, type_name = "[]int"})
	b := identity_for(&r, Key{kind = .View, address = 0, location = 0xBBB, length = 0, type_name = "[]int"})
	testing.expect(t, a != b, "two empty slices must not share an identity")
}

@(test)
equal_contents_are_not_one_object :: proc(t: ^testing.T) {
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	a := identity_for(&r, Key{kind = .View, address = 0x1000, location = 0xA, length = 3, type_name = "[]int"})
	b := identity_for(&r, Key{kind = .View, address = 0x2000, location = 0xB, length = 3, type_name = "[]int"})
	testing.expect(t, a != b, "equal contents in different storage are two objects")
}

@(test)
sub_view_shares_storage_and_keeps_its_own_length :: proc(t: ^testing.T) {
	// The sub-slice bug: a window onto a buffer drawn with the parent's length.
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	parent := identity_for(&r, Key{kind = .View, address = 0x1000, location = 0xA, length = 3, type_name = "[]int"})
	child  := identity_for(&r, Key{kind = .View, address = 0x1008, location = 0xB, length = 2, type_name = "[]int"})
	testing.expect(t, parent != child, "a sub-slice is not its parent")

	same_storage_other_length := identity_for(
		&r, Key{kind = .View, address = 0x1000, location = 0xC, length = 2, type_name = "[]int"},
	)
	testing.expect(t, same_storage_other_length != parent, "length is part of the key")
}

@(test)
identity_survives_the_same_key :: proc(t: ^testing.T) {
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	k := Key{kind = .Object, address = 0x30, location = 0x40, type_name = "Node"}
	testing.expect_value(t, identity_for(&r, k), identity_for(&r, k))
}

// The epoch guard -------------------------------------------------------

@(test)
a_budget_never_changes_an_identity :: proc(t: ^testing.T) {
	// SPEC-MEM-044. The object was hidden at step 1 because a budget cut the
	// frame that referred to it, then came back at step 2. It never died.
	// Absence of evidence is not evidence.
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	truncated := []bool{false, true, false}
	note_seen(&r, 0x1000, "Node", 0)
	advanced := advance_epoch_on_absence(&r, 0x1000, "Node", 2, truncated)
	testing.expect(t, !advanced, "a truncated step must not advance the epoch")
	testing.expect_value(t, epoch_for(&r, 0x1000, "Node"), 0)
}

@(test)
a_complete_absence_does_advance_the_epoch :: proc(t: ^testing.T) {
	// The other half. Without this the guard would be a way of never
	// advancing, and address reuse would always read as a mutation.
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	truncated := []bool{false, false, false}
	note_seen(&r, 0x1000, "Node", 0)
	advanced := advance_epoch_on_absence(&r, 0x1000, "Node", 2, truncated)
	testing.expect(t, advanced, "a complete observation of absence is evidence")
	testing.expect_value(t, epoch_for(&r, 0x1000, "Node"), 1)
}

@(test)
a_new_epoch_yields_a_new_identity :: proc(t: ^testing.T) {
	r: Registry
	registry_init(&r)
	defer registry_destroy(&r)

	before := identity_for(&r, Key{kind = .Storage, address = 0x1000, type_name = "Node", epoch = 0})
	after  := identity_for(&r, Key{kind = .Storage, address = 0x1000, type_name = "Node", epoch = 1})
	testing.expect(t, before != after, "a reused address after a real death is a new object")
}

// Assembly --------------------------------------------------------------

@(test)
assembly_refuses_a_budget_disagreement :: proc(t: ^testing.T) {
	// The core cannot verify a budget the adapter enforced at the read. The
	// declaration is the only check available, so it must actually be checked.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	s := stream_of({})
	s.budgets.elements = 999
	_, err := assemble(&a, s)
	testing.expect_value(t, err, Build_Error.Budget_Disagreement)
}

@(test)
assembly_cost_is_linear_in_steps :: proc(t: ^testing.T) {
	// THE regression test. A size check that re-serialises the accumulated
	// document at every step is O(n²), and its real consequence is that the
	// step limit becomes unreachable: a long trace dies by timeout inside the
	// measuring code. See SPEC-PERF-020.
	//
	// Asserted structurally rather than by wall time, so it cannot flake:
	// the accumulated byte count after n steps must equal the sum of the
	// per-step costs, which is only true if nothing re-measures the whole.
	build :: proc(n: int) -> (int, int) {
		a: Assembly
		assert(assembly_init(&a) == nil)
		defer assembly_destroy(&a)

		records := make([dynamic]tutor_obs.Record, context.temp_allocator)
		for i in 0 ..< n {
			vars := []tutor_obs.Variable{{name = "x", value = scalar("1")}}
			append(&records, tutor_obs.Record{index = i, file = "m.odin", line = i, frames = {one_frame(vars)}})
		}
		trace, err := assemble(&a, stream_of(records[:]))
		assert(err == .None)

		sum := 0
		for s in trace.steps {
			sum += step_cost(s)
		}
		return a.bytes_so_far, sum
	}

	sizes := []int{100, 400, 1600}
	totals: [3]int
	for n, i in sizes {
		accumulated, summed := build(n)
		// Nothing re-measures the whole document: the running total equals the
		// sum of the per-step costs.
		testing.expect_value(t, accumulated, summed)
		totals[i] = accumulated
	}

	// The growth ratio itself. Four times the steps must cost about four times
	// as much, not sixteen. ROADMAP Phase 2, acceptance 6.
	//
	// Checked as a ratio rather than as wall time so it cannot flake on a busy
	// machine, and with a generous band because per-step size varies with the
	// line number's digit count. Quadratic growth would land at 16x and is not
	// close to the band's edge.
	for i in 1 ..< len(sizes) {
		ratio := f64(totals[i]) / f64(totals[i - 1])
		testing.expect(
			t,
			ratio > 3.0 && ratio < 6.0,
			"cost must grow with the step count, not with its square",
		)
	}
}

@(test)
keyframes_appear_at_the_interval :: proc(t: ^testing.T) {
	a: Assembly
	cfg := DEFAULT_CONFIG
	cfg.keyframe_interval = 4
	assert(assembly_init(&a, cfg) == nil)
	defer assembly_destroy(&a)

	records := make([dynamic]tutor_obs.Record, context.temp_allocator)
	for i in 0 ..< 10 {
		append(&records, tutor_obs.Record{index = i, line = i, frames = {one_frame({})}})
	}
	trace, err := assemble(&a, stream_of(records[:]))
	testing.expect_value(t, err, Build_Error.None)
	testing.expect(t, trace.steps[0].keyframe, "step 0 is always a keyframe")
	testing.expect(t, trace.steps[4].keyframe, "a keyframe every K steps")
	testing.expect(t, !trace.steps[5].keyframe, "the steps between are deltas")
}

@(test)
materialise_at_k32_equals_full_snapshots :: proc(t: ^testing.T) {
	// SPEC-TRACE-002. The encoding is only correct if a materialised delta
	// step contains exactly what a full snapshot would.
	records := make([dynamic]tutor_obs.Record, context.temp_allocator)
	for i in 0 ..< 12 {
		vars := []tutor_obs.Variable {
			{name = "xs", value = view(0x1000, i % 3 + 1, 0xA)},
			{name = "ys", value = view(0x2000, 2, 0xB)},
		}
		append(&records, tutor_obs.Record{index = i, line = i, frames = {one_frame(vars)}})
	}

	// Both arenas stay alive for the comparison: a Trace points into the
	// Assembly that built it.
	delta_asm, full_asm: Assembly
	cfg_delta := DEFAULT_CONFIG; cfg_delta.keyframe_interval = 4
	cfg_full  := DEFAULT_CONFIG; cfg_full.keyframe_interval  = 1
	assert(assembly_init(&delta_asm, cfg_delta) == nil)
	assert(assembly_init(&full_asm, cfg_full) == nil)
	defer assembly_destroy(&delta_asm)
	defer assembly_destroy(&full_asm)

	delta_trace, err_a := assemble(&delta_asm, stream_of(records[:]))
	full_trace,  err_b := assemble(&full_asm, stream_of(records[:]))
	testing.expect_value(t, err_a, Build_Error.None)
	testing.expect_value(t, err_b, Build_Error.None)

	for i in 0 ..< 12 {
		from_delta, ok_a := materialise(delta_trace, i, context.temp_allocator)
		from_full,  ok_b := materialise(full_trace, i, context.temp_allocator)
		testing.expect(t, ok_a && ok_b, "materialisation must succeed")
		testing.expect_value(t, len(from_delta), len(from_full))
		for e, j in from_delta {
			testing.expect_value(t, e.id, from_full[j].id)
			testing.expect_value(t, e.length, from_full[j].length)
		}
	}
}

@(test)
a_return_value_is_shown_only_for_its_own_invocation :: proc(t: ^testing.T) {
	// The measured failure this guards against: a frame holding n = 0 reported
	// that it returned 8, which is the answer for fib(6). Attribution is by
	// frame key, and a mismatch withholds rather than guesses.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	mine   := one_frame({}, pc = 0x100, sp = 0x200)
	record := tutor_obs.Record {
		index = 0, line = 3, frames = {mine},
		returned = {{caller_pc = 0x100, caller_sp = 0x999, procedure = "fib", value = scalar("8")}},
	}
	trace, err := assemble(&a, stream_of({record}))
	testing.expect_value(t, err, Build_Error.None)
	testing.expect_value(t, trace.steps[0].frames[0].returned_text, "")
}

@(test)
a_matching_return_value_is_shown :: proc(t: ^testing.T) {
	// The other half of the pair. Without it, the test above passes by
	// showing nothing ever, which is exactly how a prior system's
	// "return never lies" check became vacuously true. See SPEC-TEST-022.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	// `one_frame` names its procedure "main", and the returned record must name
	// the SAME procedure. It used to say "soma" and still matched, because
	// attribution compared only the return address and the stack pointer - so a
	// return from one procedure was attributed to a frame of another. That is a
	// wrong return value, and SPEC-MEM-060's key has three parts for this reason.
	mine   := one_frame({}, pc = 0x100, sp = 0x200)
	record := tutor_obs.Record {
		index = 0, line = 3, frames = {mine},
		returned = {{caller_pc = 0x100, caller_sp = 0x200, procedure = "main", value = scalar("24")}},
	}
	trace, _ := assemble(&a, stream_of({record}))
	testing.expect_value(t, trace.steps[0].frames[0].returned_text, "24")
}

@(test)
a_return_from_a_different_procedure_is_withheld :: proc(t: ^testing.T) {
	// Same call site, same stack slot, different procedure. Two procedures can
	// be called from one address at different times, and the stack pointer is
	// reused. Only the name separates them.
	//
	// SPEC-MEM-061: when the invocation cannot be determined, record nothing. A
	// measured failure from a working system had a frame holding n = 0 report
	// that it returned 8, the answer for fib(6). No return value teaches
	// nothing, which is better than teaching that fib(0) is 8.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	mine   := one_frame({}, pc = 0x100, sp = 0x200)
	record := tutor_obs.Record {
		index = 0, line = 3, frames = {mine},
		returned = {{caller_pc = 0x100, caller_sp = 0x200, procedure = "other", value = scalar("24")}},
	}
	trace, _ := assemble(&a, stream_of({record}))
	testing.expect_value(t, trace.steps[0].frames[0].returned_text, "")
}

@(test)
a_return_is_attributed_to_the_step_where_its_frame_was_live :: proc(t: ^testing.T) {
	// A return is observed AFTER its frame has left the stack, so it is never
	// attributable to a frame in the record that carries it. It belongs to the
	// invocation that produced it, which is on screen at the earlier steps.
	//
	// Step 0 and 1 hold the callee. Step 2 is back in the caller and carries the
	// return. The value must land on step 1 - the LAST step where the callee was
	// live - and nowhere else.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	callee := one_frame({}, pc = 0x100, sp = 0x200)
	caller := one_frame({}, pc = 0x900, sp = 0x800)
	trace, _ := assemble(&a, stream_of({
		{index = 0, line = 1, frames = {callee}},
		{index = 1, line = 2, frames = {callee}},
		{index = 2, line = 3, frames = {caller},
		 returned = {{caller_pc = 0x100, caller_sp = 0x200, procedure = "main", value = scalar("42")}}},
	}))

	testing.expect_value(t, trace.steps[0].frames[0].returned_text, "")
	testing.expect_value(t, trace.steps[1].frames[0].returned_text, "42")
	testing.expect_value(t, trace.steps[2].frames[0].returned_text, "")
}

@(test)
the_four_states_survive_assembly :: proc(t: ^testing.T) {
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	vars := []tutor_obs.Variable {
		{name = "ok",      value = scalar("1")},
		{name = "later",   value = {state = .Not_Yet_Active, type_name = "int"}},
		{name = "gone",    value = {state = .Unreadable, type_name = "^int", reason = "address not mapped"}},
		{name = "corrupt", value = {state = .Unknown, type_name = "[]int", reason = "length failed validation"}},
	}
	trace, _ := assemble(&a, stream_of({{index = 0, line = 1, frames = {one_frame(vars)}}}))
	slots := trace.steps[0].frames[0].slots

	testing.expect_value(t, slots[0].state, Value_State.Valid)
	testing.expect_value(t, slots[1].state, Value_State.Not_Yet_Active)
	testing.expect_value(t, slots[2].state, Value_State.Unreadable)
	testing.expect_value(t, slots[3].state, Value_State.Unknown)
	// A reason must reach the student. "Unknown" with no cause teaches nothing.
	testing.expect_value(t, slots[3].reason, "length failed validation")
}

@(test)
a_truncation_is_recorded_at_its_step :: proc(t: ^testing.T) {
	a: Assembly
	cfg := DEFAULT_CONFIG
	cfg.objects_per_step = 2
	assert(assembly_init(&a, cfg) == nil)
	defer assembly_destroy(&a)

	vars := make([dynamic]tutor_obs.Variable, context.temp_allocator)
	for i in 0 ..< 5 {
		append(&vars, tutor_obs.Variable{
			name = "v", value = view(u64(0x1000 + i * 0x100), 1, u64(0xA00 + i)),
		})
	}
	trace, _ := assemble(&a, stream_of({{index = 0, line = 1, frames = {one_frame(vars[:])}}}))
	testing.expect(t, len(trace.steps[0].truncations) > 0, "a reached budget must be visible at the step")
}

@(test)
a_trace_round_trips_through_json :: proc(t: ^testing.T) {
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	vars := []tutor_obs.Variable{{name = "x", value = scalar("42")}}
	trace, _ := assemble(&a, stream_of({{index = 0, file = "m.odin", line = 7, frames = {one_frame(vars)}}}))

	data, ok := encode(trace, context.temp_allocator)
	testing.expect(t, ok, "a trace must encode")
	back, ok2 := decode(data, context.temp_allocator)
	testing.expect(t, ok2, "and decode")
	testing.expect_value(t, len(back.steps), 1)
	testing.expect_value(t, back.steps[0].line, 7)
	testing.expect_value(t, back.steps[0].frames[0].slots[0].text, "42")
}

@(test)
an_unknown_trace_version_is_refused :: proc(t: ^testing.T) {
	// Reading what we recognise from a future format is how a confident wrong
	// picture gets drawn. Refuse instead.
	bad := transmute([]byte)string(`{"trace_version":99,"steps":[]}`)
	_, ok := decode(bad, context.temp_allocator)
	testing.expect(t, !ok, "an unknown trace version must be refused")
}

@(test)
every_termination_has_a_sentence :: proc(t: ^testing.T) {
	// An enum name is not an explanation. REQ-ERR-002.
	for term in Termination {
		trace := Trace{termination = term, detail = "x"}
		msg := describe_termination(trace, context.temp_allocator)
		testing.expect(t, len(msg) > 10, "every termination needs a sentence for the student")
	}
}

@(test)
a_sub_slice_shares_its_parents_storage_and_keeps_its_own_length :: proc(t: ^testing.T) {
	// The anti-lie case, end to end through assembly.
	//
	// `notas` and `notas[1:]` have different data pointers — measured, eight
	// bytes apart — so keying storage by the view's own pointer gives two
	// storages and the sharing never appears. Grouping is by overlap.
	//
	// Both halves matter: they must share the storage, AND they must keep
	// their own lengths. Showing the sub-slice with the parent's length is the
	// original bug this whole fixture exists for.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	parent := tutor_obs.Value {
		state = .Valid, kind = .Slice, type_name = "[]int",
		data = 0x1000, length = 3, elem_size = 8, address = 0xA,
	}
	child := tutor_obs.Value {
		state = .Valid, kind = .Slice, type_name = "[]int",
		data = 0x1008, length = 2, elem_size = 8, address = 0xB,
	}
	vars := []tutor_obs.Variable{{name = "notas", value = parent}, {name = "sub", value = child}}
	trace, err := assemble(&a, stream_of({{index = 0, line = 1, frames = {one_frame(vars)}}}))
	testing.expect_value(t, err, Build_Error.None)

	entities, ok := materialise(trace, 0, context.temp_allocator)
	testing.expect(t, ok, "the step must materialise")
	testing.expect_value(t, len(entities), 2)

	testing.expect(t, entities[0].id != entities[1].id, "two views are two identities")
	testing.expect_value(t, entities[0].shares_storage_with, entities[1].shares_storage_with)
	testing.expect(t, entities[0].shares_storage_with != NO_ID, "the shared storage must be named")

	lengths := [2]int{entities[0].length, entities[1].length}
	testing.expect(t, lengths == {3, 2} || lengths == {2, 3}, "each view keeps its own length")
}

@(test)
two_unrelated_buffers_do_not_share_storage :: proc(t: ^testing.T) {
	// The other half. Without it, "everything overlaps" would pass the test
	// above, and every slice in the program would look like one buffer.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	one := tutor_obs.Value {
		state = .Valid, kind = .Slice, type_name = "[]int",
		data = 0x1000, length = 3, elem_size = 8, address = 0xA,
	}
	other := tutor_obs.Value {
		state = .Valid, kind = .Slice, type_name = "[]int",
		data = 0x9000, length = 3, elem_size = 8, address = 0xB,
	}
	vars := []tutor_obs.Variable{{name = "a", value = one}, {name = "b", value = other}}
	trace, _ := assemble(&a, stream_of({{index = 0, line = 1, frames = {one_frame(vars)}}}))
	entities, _ := materialise(trace, 0, context.temp_allocator)

	// Neither carries a sharing mark at all. Sitting on a storage is not sharing
	// it: each of these views is the only one on its buffer, so each shares with
	// nobody.
	//
	// This assertion used to read `entities[0].shares_storage_with !=
	// entities[1].shares_storage_with`, which passed for the wrong reason — the
	// two views held two DIFFERENT storage identities, and both were shown to
	// the student as "shares storage". The intent was always "these two are not
	// one buffer"; the mechanism it checked stopped expressing it.
	testing.expect_value(t, entities[0].shares_storage_with, NO_ID)
	testing.expect_value(t, entities[1].shares_storage_with, NO_ID)
}

@(test)
a_lone_view_is_never_marked_as_sharing :: proc(t: ^testing.T) {
	// THE LIE THIS PREVENTS: "shares storage" on a slice that shares with
	// nothing. Every slice in a program sits on a storage, so a mark set
	// whenever a storage exists is a mark that is always on — and a student
	// reads it as a relationship rather than as punctuation.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	only := tutor_obs.Value {
		state = .Valid, kind = .Slice, type_name = "[]int",
		data = 0x1000, length = 3, elem_size = 8, address = 0xA,
	}
	vars := []tutor_obs.Variable{{name = "only", value = only}}
	trace, _ := assemble(&a, stream_of({{index = 0, line = 1, frames = {one_frame(vars)}}}))
	entities, _ := materialise(trace, 0, context.temp_allocator)

	testing.expect_value(t, len(entities), 1)
	testing.expect_value(t, entities[0].shares_storage_with, NO_ID)
}

@(test)
two_empty_views_are_two_objects :: proc(t: ^testing.T) {
	// THE LIE THIS PREVENTS: two empty slices become one object.
	//
	// Both are {data: 0x0, len: 0} and are byte-identical, so only the address
	// of the variable holding each one separates them (SPEC-MEM-006). The
	// adapter reports that under `address`; when it did not, both collapsed into
	// a single identity and the student saw one variable where two existed.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	first := tutor_obs.Value {
		state = .Valid, kind = .Slice, type_name = "[]int", data = 0, length = 0, address = 0xA,
	}
	second := tutor_obs.Value {
		state = .Valid, kind = .Slice, type_name = "[]int", data = 0, length = 0, address = 0xB,
	}
	vars := []tutor_obs.Variable {
		{name = "empty1", value = first},
		{name = "empty2", value = second},
	}
	trace, _ := assemble(&a, stream_of({{index = 0, line = 1, frames = {one_frame(vars)}}}))

	slots := trace.steps[0].frames[0].slots
	testing.expect_value(t, len(slots), 2)
	testing.expect(t, slots[0].refers_to != slots[1].refers_to, "two empty slices are two objects")
}

@(test)
a_cycle_shows_the_objects_own_identity :: proc(t: ^testing.T) {
	// THE LIE THIS PREVENTS: a cycle drawn as an endless chain of distinct
	// objects, or an expansion that never terminates.
	//
	// The node points at itself. Its identity must already exist when its own
	// field is resolved, which is why identities are minted for every
	// discovered object BEFORE any of them is built. Minting as we go would
	// leave the self-reference unresolvable, and unresolvable renders as a
	// pointer into nothing — a cycle drawn as a dead end.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	SELF :: u64(0x4000)
	node := tutor_obs.Value {
		state = .Valid, kind = .Struct, type_name = "main::Node", address = SELF,
		members = []tutor_obs.Variable {
			{name = "value", value = {state = .Valid, kind = .Scalar, type_name = "int", text = "7"}},
			{name = "next", value = {state = .Valid, kind = .Pointer, type_name = "^Node", data = SELF}},
		},
	}
	pointer := tutor_obs.Value {
		state = .Valid, kind = .Pointer, type_name = "^Node", data = SELF, address = 0xA,
	}
	vars := []tutor_obs.Variable{{name = "node", value = pointer}}
	record := tutor_obs.Record {
		index = 0, line = 1,
		frames = {one_frame(vars)},
		objects = []tutor_obs.Discovered{{address = SELF, value = node}},
	}
	trace, _ := assemble(&a, stream_of({record}))
	entities, _ := materialise(trace, 0, context.temp_allocator)

	testing.expect_value(t, len(entities), 1)
	self := entities[0]
	testing.expect_value(t, len(self.members), 2)
	// The field refers to the object it lives in. That is what tells a student
	// it is a cycle rather than a picture that ran out of room.
	testing.expect_value(t, self.members[1].refers_to, self.id)
	// And the variable points at the same object, not a copy of it.
	testing.expect_value(t, trace.steps[0].frames[0].slots[0].refers_to, self.id)
}

@(test)
an_unfollowed_pointer_refers_to_nothing :: proc(t: ^testing.T) {
	// SPEC-MEM-031: a rawptr, a procedure pointer, a pointer to a scalar, and a
	// pointer whose target type is absent are never followed. The model must
	// then produce a pointer value with NO reference.
	//
	// A reference invented here is a fabricated object, which is the failure
	// the whole project is built against.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	unshaped := tutor_obs.Value {
		state = .Valid, kind = .Pointer, type_name = "rawptr",
		data = 0x9999, text = "->", address = 0xA,
	}
	vars := []tutor_obs.Variable{{name = "unshaped", value = unshaped}}
	// No `objects`: the adapter followed nothing, so the core knows nothing.
	trace, _ := assemble(&a, stream_of({{index = 0, line = 1, frames = {one_frame(vars)}}}))

	slot := trace.steps[0].frames[0].slots[0]
	testing.expect_value(t, slot.refers_to, NO_ID)
	testing.expect_value(t, slot.text, "->")
}

@(test)
free_then_allocate_without_a_free_event_still_reuses_the_identity :: proc(t: ^testing.T) {
	// REPLACED BY PHASE 6a, 2026-08-05. SPEC-TEST-021 required that this be
	// replaced rather than quietly deleted, so here is what changed and why.
	//
	// It used to be named `..._which_is_WRONG` and it asserted a version 1
	// incorrectness: an object freed and an object allocated at the same address
	// were indistinguishable, so the second inherited the first's identity.
	//
	// Phase 6a gave the model positive evidence — the adapter records what the
	// program handed back to the allocator — and the companion test below shows
	// two identities for the two objects.
	//
	// This test survives because the stream here carries NO free event, and that
	// case is still real: a toolchain whose allocator entry point does not
	// resolve, or an allocator the adapter does not watch. Without evidence of
	// death the model must not invent one, so the identity is still reused. What
	// changed is that this is now a statement about MISSING EVIDENCE rather than
	// about a limit of the model.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	REUSED :: u64(0x5000)
	holder :: u64(0xA)

	// Step 0: the first object. Step 1: the second, at the same address. The
	// adapter reached both, so both are complete observations - there is no
	// truncation anywhere to excuse the collapse.
	// Built inline rather than by a helper: Odin refuses to return a compound
	// literal holding a slice, because the slice would point into the callee's
	// frame. These live in this test's frame, which outlives the assembly call.
	members_first := []tutor_obs.Variable {
		{name = "value", value = {state = .Valid, kind = .Scalar, type_name = "int", text = "1"}},
	}
	members_second := []tutor_obs.Variable {
		{name = "value", value = {state = .Valid, kind = .Scalar, type_name = "int", text = "2"}},
	}
	object_first := tutor_obs.Value {
		state = .Valid, kind = .Struct, type_name = "main::Node", address = REUSED,
		members = members_first,
	}
	object_second := tutor_obs.Value {
		state = .Valid, kind = .Struct, type_name = "main::Node", address = REUSED,
		members = members_second,
	}
	pointer := tutor_obs.Value {
		state = .Valid, kind = .Pointer, type_name = "^Node", data = REUSED, address = holder,
	}
	vars := []tutor_obs.Variable{{name = "p", value = pointer}}

	trace, _ := assemble(&a, stream_of({
		{index = 0, line = 1, frames = {one_frame(vars)},
		 objects = []tutor_obs.Discovered{{address = REUSED, value = object_first}}},
		{index = 1, line = 2, frames = {one_frame(vars)},
		 objects = []tutor_obs.Discovered{{address = REUSED, value = object_second}}},
	}))

	first := trace.steps[0].frames[0].slots[0].refers_to
	second := trace.steps[1].frames[0].slots[0].refers_to

	testing.expect(t, first != NO_ID, "both steps refer to an object")
	testing.expect_value(t, first, second)
}

@(test)
a_recorded_free_gives_the_next_allocation_a_new_identity :: proc(t: ^testing.T) {
	// PHASE 6a, and the close of REQ-MEM-003.
	//
	// The same shape as the test above with ONE difference: the program told us
	// the storage died. That is positive evidence, and it needs no guard —
	// ADR-011's caution is about ABSENCE, which a budget can fake. A free event
	// cannot be faked by a budget.
	a: Assembly
	assert(assembly_init(&a) == nil)
	defer assembly_destroy(&a)

	REUSED :: u64(0x5000)
	members_first := []tutor_obs.Variable {
		{name = "value", value = {state = .Valid, kind = .Scalar, type_name = "int", text = "1"}},
	}
	members_second := []tutor_obs.Variable {
		{name = "value", value = {state = .Valid, kind = .Scalar, type_name = "int", text = "2"}},
	}
	object_first := tutor_obs.Value {
		state = .Valid, kind = .Struct, type_name = "main::Node", address = REUSED,
		members = members_first,
	}
	object_second := tutor_obs.Value {
		state = .Valid, kind = .Struct, type_name = "main::Node", address = REUSED,
		members = members_second,
	}
	pointer := tutor_obs.Value {
		state = .Valid, kind = .Pointer, type_name = "^Node", data = REUSED, address = 0xA,
	}
	vars := []tutor_obs.Variable{{name = "p", value = pointer}}

	trace, _ := assemble(&a, stream_of({
		{index = 0, line = 1, frames = {one_frame(vars)},
		 objects = []tutor_obs.Discovered{{address = REUSED, value = object_first}}},
		// The step that carries the death.
		{index = 1, line = 2, frames = {one_frame(vars)},
		 objects = []tutor_obs.Discovered{{address = REUSED, value = object_second}},
		 freed = []u64{REUSED}},
	}))

	first := trace.steps[0].frames[0].slots[0].refers_to
	second := trace.steps[1].frames[0].slots[0].refers_to
	testing.expect(t, first != NO_ID && second != NO_ID, "both steps refer to an object")
	testing.expect(t, first != second, "two objects lived at one address, so there are two identities")
}

@(test)
a_truncated_step_does_not_break_an_identity :: proc(t: ^testing.T) {
	// ROADMAP Phase 2, acceptance 8. SPEC-MEM-044, ADR-011.
	//
	// The object is present, then a budget hides it, then it is present again.
	// It never died: the reachable set is a property of OUR traversal, not of
	// the program, so absence under a budget is not evidence of death.
	//
	// If a budget could change an identity, then looking at a program would
	// change what the program is - and the student would see an object
	// replaced by a different one because the tool ran out of room.
	a: Assembly
	cfg := DEFAULT_CONFIG
	cfg.objects_per_step = 1
	assert(assembly_init(&a, cfg) == nil)
	defer assembly_destroy(&a)

	LIVE :: u64(0x6000)
	OTHER :: u64(0x7000)

	members := []tutor_obs.Variable {
		{name = "v", value = {state = .Valid, kind = .Scalar, type_name = "int", text = "1"}},
	}
	live := tutor_obs.Discovered {
		address = LIVE,
		value = {
			state = .Valid, kind = .Struct, type_name = "main::Node",
			address = LIVE, members = members,
		},
	}
	other := tutor_obs.Discovered {
		address = OTHER,
		value = {
			state = .Valid, kind = .Struct, type_name = "main::Other",
			address = OTHER, members = members,
		},
	}
	pointer := tutor_obs.Value {
		state = .Valid, kind = .Pointer, type_name = "^Node", data = LIVE, address = 0xA,
	}
	vars := []tutor_obs.Variable{{name = "p", value = pointer}}

	// Step 1 offers two objects with a budget of one, so the step is truncated
	// and the object that matters is the one that got cut.
	trace, _ := assemble(&a, stream_of({
		{index = 0, line = 1, frames = {one_frame(vars)}, objects = []tutor_obs.Discovered{live}},
		{index = 1, line = 2, frames = {one_frame(vars)}, objects = []tutor_obs.Discovered{other, live}},
		{index = 2, line = 3, frames = {one_frame(vars)}, objects = []tutor_obs.Discovered{live}},
	}))

	testing.expect(t, len(trace.steps[1].truncations) > 0, "step 1 must record that a budget cut it")

	before := trace.steps[0].frames[0].slots[0].refers_to
	after := trace.steps[2].frames[0].slots[0].refers_to
	testing.expect(t, before != NO_ID, "the object has an identity to keep")
	testing.expect_value(t, before, after)
}

@(test)
a_complete_absence_does_change_the_identity_end_to_end :: proc(t: ^testing.T) {
	// The companion to a_truncated_step_does_not_break_an_identity, and the
	// reason that test means anything.
	//
	// If the epoch never advanced, the guard would be doing no work and the
	// truncation test would pass while asserting nothing - the vacuous-check
	// failure SPEC-TEST-022 was written against. That is not hypothetical here:
	// the epoch procedures WERE only reachable from tests until this was wired,
	// so the guard was provably inert and its test provably empty.
	//
	// Same three-step shape, one difference: nothing is truncated, so the
	// absence at step 1 is a complete observation. The address then IS evidence
	// of a new allocation, and the identity must change.
	a: Assembly
	assert(assembly_init(&a) == nil)   // the default budget cuts nothing
	defer assembly_destroy(&a)

	LIVE :: u64(0x6000)
	members := []tutor_obs.Variable {
		{name = "v", value = {state = .Valid, kind = .Scalar, type_name = "int", text = "1"}},
	}
	live := tutor_obs.Discovered {
		address = LIVE,
		value = {
			state = .Valid, kind = .Struct, type_name = "main::Node",
			address = LIVE, members = members,
		},
	}
	pointer := tutor_obs.Value {
		state = .Valid, kind = .Pointer, type_name = "^Node", data = LIVE, address = 0xA,
	}
	vars := []tutor_obs.Variable{{name = "p", value = pointer}}
	// Step 1 has no objects at all, and no budget was reached.
	empty := []tutor_obs.Variable{}

	trace, _ := assemble(&a, stream_of({
		{index = 0, line = 1, frames = {one_frame(vars)}, objects = []tutor_obs.Discovered{live}},
		{index = 1, line = 2, frames = {one_frame(empty)}},
		{index = 2, line = 3, frames = {one_frame(vars)}, objects = []tutor_obs.Discovered{live}},
	}))

	testing.expect_value(t, len(trace.steps[1].truncations), 0)

	before := trace.steps[0].frames[0].slots[0].refers_to
	after := trace.steps[2].frames[0].slots[0].refers_to
	testing.expect(t, before != NO_ID && after != NO_ID, "both steps refer to an object")
	testing.expect(
		t,
		before != after,
		"an address that vanished from a complete observation and came back is a new object",
	)
}
