package tutor_render

import "core:strings"
import "core:testing"
import tutor_model "../model"

@(test)
a_golden_shows_all_four_states_at_once :: proc(t: ^testing.T) {
	// SPEC-TEST-061. One screen carries all four states, so a change that
	// merges any two of them fails here rather than reaching a student.
	trace := tutor_model.Trace {
		steps = {
			{
				index = 0, file = "m.odin", line = 12, keyframe = true, stdout_len = 4,
				frames = {
					{
						id = 1, procedure = "main", line = 12,
						slots = {
							{name = "total",   state = .Valid,          text = "24"},
							{name = "later",   state = .Not_Yet_Active},
							{name = "gone",    state = .Unreadable,     reason = "address not mapped"},
							{name = "corrupt", state = .Unknown,        reason = "length failed validation"},
						},
					},
				},
			},
		},
	}
	out := step(trace, 0, {}, PLAIN, context.temp_allocator)

	testing.expect(t, strings.contains(out, "total = 24"), "a valid value shows its value")
	testing.expect(t, strings.contains(out, "later (not created yet)"), "not-yet-active has its own words")
	testing.expect(t, strings.contains(out, "gone (could not be read)"), "unreadable has its own words")
	testing.expect(t, strings.contains(out, "corrupt (unknown)"), "unknown has its own words")
	testing.expect(t, strings.contains(out, "length failed validation"), "the reason reaches the student")
}

@(test)
the_four_state_marks_are_all_different :: proc(t: ^testing.T) {
	seen := make(map[string]bool, context.temp_allocator)
	for state in tutor_model.Value_State {
		mark := state_mark(state)
		testing.expect(t, !(mark in seen), "two states must never share a visible form")
		seen[mark] = true
	}
}

@(test)
an_empty_frame_does_not_claim_there_are_no_variables :: proc(t: ^testing.T) {
	// REQ-MEM-008. At a procedure's first line the arguments exist but are not
	// readable yet. "no variables" is a claim, and it is false.
	trace := tutor_model.Trace {
		steps = {{index = 0, file = "m.odin", line = 3, frames = {{id = 1, procedure = "fib", line = 3}}}},
	}
	out := step(trace, 0, {}, PLAIN, context.temp_allocator)
	testing.expect(t, strings.contains(out, "no variables in scope at this line"), "say what is true")
	testing.expect(t, !strings.contains(out, "has no variables"), "do not claim the procedure has none")
}

@(test)
aliasing_shows_as_two_slots_with_one_label :: proc(t: ^testing.T) {
	// ADR-007: no arrows. Two names for one object is two identical labels.
	trace := tutor_model.Trace {
		steps = {
			{
				index = 0, file = "m.odin", line = 5, keyframe = true,
				frames = {
					{
						id = 1, procedure = "main", line = 5,
						slots = {
							{name = "xs", state = .Valid, refers_to = 7},
							{name = "ys", state = .Valid, refers_to = 7},
						},
					},
				},
			},
		},
	}
	out := step(trace, 0, {{id = 7, kind = .View, type_name = "[]int", length = 3}}, PLAIN, context.temp_allocator)
	testing.expect(t, strings.contains(out, "xs -> #7"), "the first name carries the label")
	testing.expect(t, strings.contains(out, "ys -> #7"), "and so does the second")
}

@(test)
shared_storage_is_marked_differently_from_aliasing :: proc(t: ^testing.T) {
	// SPEC-TUI-020. Two windows onto one buffer is not the same fact as two
	// names for one object. One mark for both reintroduces the sub-slice bug
	// at the presentation layer.
	entities := []tutor_model.Entity {
		{id = 7, kind = .View, type_name = "[]int", length = 3, shares_storage_with = 9},
		{id = 8, kind = .View, type_name = "[]int", length = 2, shares_storage_with = 9},
	}
	trace := tutor_model.Trace{steps = {{index = 0, file = "m.odin", line = 5, keyframe = true}}}
	out := step(trace, 0, entities, PLAIN, context.temp_allocator)

	testing.expect(t, strings.contains(out, "#7 []int (3)"), "the parent keeps its own length")
	testing.expect(t, strings.contains(out, "#8 []int (2)"), "and the sub-slice keeps its own")
	testing.expect(t, strings.contains(out, "shares storage @9"), "sharing is stated, not implied")
}

@(test)
a_reached_budget_is_visible_on_screen :: proc(t: ^testing.T) {
	// A limit the student cannot see is a missing element that looks absent.
	trace := tutor_model.Trace {
		steps = {{index = 0, file = "m.odin", line = 2, truncations = {{what = "objects", limit = 200}}}},
	}
	out := step(trace, 0, {}, PLAIN, context.temp_allocator)
	testing.expect(t, strings.contains(out, "LIMITS REACHED"), "a limit reaches the screen")
	testing.expect(t, strings.contains(out, "200"), "and says what the limit was")
}

@(test)
the_render_contains_no_address :: proc(t: ^testing.T) {
	// REQ-MEM-001. An address in the picture teaches the student to think in
	// addresses, and would make two runs of one fixture differ on screen.
	trace := tutor_model.Trace {
		steps = {
			{
				index = 0, file = "m.odin", line = 5, keyframe = true,
				frames = {{id = 1, procedure = "main", line = 5, slots = {{name = "p", state = .Valid, refers_to = 3}}}},
			},
		},
	}
	out := step(trace, 0, {{id = 3, kind = .Object, type_name = "Node"}}, PLAIN, context.temp_allocator)
	testing.expect(t, !strings.contains(out, "0x"), "no hexadecimal address may appear in the picture")
}
