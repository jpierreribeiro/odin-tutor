// Package tutor_render turns a materialised step into text.
//
// It draws no arrows and computes no graph layout. A terminal is a character
// grid, so a reference is shown as a label and aliasing appears as two slots
// carrying the same label. See ADR-007.
//
// Everything here is text, so a golden test asserts the picture directly
// rather than asserting that no error occurred. See SPEC-TEST-060.
package tutor_render

import "core:fmt"
import "core:strings"
import tutor_model "../model"

// Style says how much decoration the terminal gets. Colour and Unicode are
// decoration: removing both loses no information. See SPEC-TUI-040.
Style :: struct {
	unicode: bool,
	colour:  bool,
}

PLAIN :: Style{unicode = false, colour = false}

// state_mark is the visible form of each value state.
//
// The four never share a form. Merging any two of them — "both are blank" —
// tells the student that "not created yet" and "I could not read it" are the
// same thing, and they are not. See ADR-008, SPEC-TEST-061.
state_mark :: proc(state: tutor_model.Value_State) -> string {
	switch state {
	case .Valid:          return ""
	case .Not_Yet_Active: return "(not created yet)"
	case .Unreadable:     return "(could not be read)"
	case .Unknown:        return "(unknown)"
	}
	return "(unknown)"
}

// step renders one step, given its materialised entities.
step :: proc(
	trace: tutor_model.Trace,
	index: int,
	entities: []tutor_model.Entity,
	style := PLAIN,
	allocator := context.allocator,
) -> string {
	b := strings.builder_make(allocator)
	s := trace.steps[index]

	fmt.sbprintf(&b, "STEP %d/%d   %s:%d\n\n", index + 1, len(trace.steps), s.file, s.line)

	fmt.sbprintln(&b, "FRAMES")
	if len(s.frames) == 0 {
		fmt.sbprintln(&b, "  (none)")
	}
	for frame in s.frames {
		fmt.sbprintf(&b, "  %s()\n", frame.procedure)
		if len(frame.slots) == 0 {
			// "no variables" is a claim, and it is often false: a frame at its
			// first line has variables that are not readable yet. Say that
			// instead. See REQ-MEM-008.
			fmt.sbprintln(&b, "    (no variables in scope at this line)")
		}
		for slot in frame.slots {
			write_slot(&b, slot, 4)
		}
		if frame.returned_text != "" {
			fmt.sbprintf(&b, "    returned %s\n", frame.returned_text)
		}
	}

	fmt.sbprintln(&b, "\nOBJECTS")
	if len(entities) == 0 {
		fmt.sbprintln(&b, "  (none)")
	}
	for e in entities {
		write_entity(&b, e)
	}

	if len(s.truncations) > 0 {
		fmt.sbprintln(&b, "\nLIMITS REACHED AT THIS STEP")
		for t in s.truncations {
			fmt.sbprintf(&b, "  %s: showing at most %d\n", t.what, t.limit)
		}
	}

	fmt.sbprintf(&b, "\nOUTPUT SO FAR: %d bytes\n", s.stdout_len)
	return strings.to_string(b)
}

write_slot :: proc(b: ^strings.Builder, slot: tutor_model.Slot, indent: int) {
	pad := strings.repeat(" ", indent, context.temp_allocator)
	if slot.state != .Valid {
		fmt.sbprintf(b, "%s%s %s", pad, slot.name, state_mark(slot.state))
		if slot.reason != "" {
			fmt.sbprintf(b, " — %s", slot.reason)
		}
		fmt.sbprintln(b, "")
		return
	}
	if slot.refers_to != tutor_model.NO_ID {
		fmt.sbprintf(b, "%s%s -> #%d\n", pad, slot.name, int(slot.refers_to))
		return
	}
	fmt.sbprintf(b, "%s%s = %s\n", pad, slot.name, slot.text)
}

write_entity :: proc(b: ^strings.Builder, e: tutor_model.Entity) {
	fmt.sbprintf(b, "  #%d %s", int(e.id), e.type_name)
	if e.length > 0 {
		fmt.sbprintf(b, " (%d)", e.length)
	}
	if e.text != "" {
		fmt.sbprintf(b, " %s", e.text)
	}
	// Aliasing and shared storage are different relations and must not share a
	// mark. Two names for one object is not the same fact as two windows onto
	// one buffer, and collapsing them reintroduces the sub-slice bug at the
	// presentation layer. See SPEC-TUI-020.
	if e.shares_storage_with != tutor_model.NO_ID {
		fmt.sbprintf(b, "  [shares storage @%d]", int(e.shares_storage_with))
	}
	fmt.sbprintln(b, "")
	for m in e.members {
		write_slot(b, m, 6)
	}
}
