// Package tutor_render turns a materialised step into text.
//
// It draws no arrows and computes no graph layout. A terminal is a character
// grid, so a reference is shown as a label and aliasing appears as two slots
// carrying the same label. See ADR-007.
//
// THIS IS THE ONLY FORMATTER. The interactive interface places this output into
// a layout; it does not format anything itself. Two implementations of the same
// screen drift, and the one nobody looks at drifts first (SPEC-TUI-051).
//
// Everything here is text, so a golden test asserts the picture directly rather
// than asserting that no error occurred. See SPEC-TEST-060.
package tutor_render

import "core:fmt"
import "core:strings"
import tutor_model "../model"

// Style says how much decoration the terminal gets.
//
// Colour and Unicode are decoration: removing both loses no information
// (SPEC-TUI-041, SPEC-TUI-042). Every distinction colour makes is also made by
// a character or a word, which is what lets a golden test read the screen.
Style :: struct {
	unicode: bool,
	colour:  bool,
}

PLAIN :: Style{unicode = false, colour = false}
FANCY :: Style{unicode = true, colour = false}

// MIN_COLUMNS and MIN_ROWS are stated, not assumed. Below this the interface
// reports that the terminal is too small rather than drawing something wrong.
// See SPEC-TUI-044.
MIN_COLUMNS :: 60
MIN_ROWS :: 20

// CIRCLED_ONE is `①`. The circled digits run to `⑳` and then stop, so a label
// past twenty falls back to the bracket form rather than to some other glyph
// the student has never seen.
CIRCLED_ONE :: 0x2460
CIRCLED_LAST :: 20

// label renders an identity the way both the screen and the plain text show it.
//
// The same label appears at both ends of a reference. That is the whole
// reference mechanism: two `-> ②` in different frames is aliasing, and a field
// of ② that reads `-> ②` is a cycle. Both are legible without a layout
// algorithm. See SPEC-TUI-002.
label :: proc(id: tutor_model.Id, style: Style, allocator := context.temp_allocator) -> string {
	n := int(id)
	if style.unicode && n >= 1 && n <= CIRCLED_LAST {
		return fmt.aprintf("%r", rune(CIRCLED_ONE + n - 1), allocator = allocator)
	}
	return fmt.aprintf("[%d]", n, allocator = allocator)
}

// state_mark is the visible form of each value state.
//
// The four never share a form, and none of them is blank. An empty slot is
// indistinguishable from "there is nothing here", which is a claim about the
// program (SPEC-TUI-010). Merging any two of them — "both render blank" — tells
// the student that "not created yet" and "I could not read it" are the same
// thing. See ADR-008, SPEC-TUI-003.
state_mark :: proc(state: tutor_model.Value_State, style: Style) -> string {
	switch state {
	case .Valid:
		return ""
	case .Not_Yet_Active:
		return style.unicode ? "· not yet" : "- not yet"
	case .Unreadable:
		return style.unicode ? "✗ unreadable" : "! unreadable"
	case .Unknown:
		return "? unknown"
	}
	return "? unknown"
}

// Screen is everything one rendering needs.
//
// `source` may be empty: the trace does not carry the student's text, and a
// caller that could not read the file draws the other three regions rather than
// failing. Missing source is not missing information about memory.
Screen :: struct {
	trace:    tutor_model.Trace,
	index:    int,
	entities: []tutor_model.Entity,
	source:   []string,
	style:    Style,
	// context_lines is how many lines of source to show either side of the
	// current one. Zero means the whole region is dropped.
	context_lines: int,
}

DEFAULT_CONTEXT_LINES :: 4

// step renders one step. The four regions of SPEC-TUI-001, in order.
step :: proc(
	trace: tutor_model.Trace,
	index: int,
	entities: []tutor_model.Entity,
	style := PLAIN,
	allocator := context.allocator,
) -> string {
	return screen(
		Screen {
			trace = trace,
			index = index,
			entities = entities,
			style = style,
			context_lines = 0,
		},
		allocator,
	)
}

screen :: proc(s: Screen, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	step := s.trace.steps[s.index]

	// The status line names the step, the location, and the procedure.
	procedure := len(step.frames) > 0 ? step.frames[0].procedure : ""
	fmt.sbprintf(
		&b, "STEP %d/%d   %s:%d   %s\n\n",
		s.index + 1, len(s.trace.steps), step.file, step.line, procedure,
	)

	if s.context_lines > 0 && len(s.source) > 0 {
		write_source(&b, s, step.line)
		fmt.sbprintln(&b, "")
	}

	fmt.sbprintln(&b, "FRAMES")
	if len(step.frames) == 0 {
		fmt.sbprintln(&b, "  (none)")
	}
	for frame in step.frames {
		fmt.sbprintf(&b, "  %s()\n", frame.procedure)
		if len(frame.slots) == 0 {
			// "(no variables)" is a claim, and at a procedure's entry step it is
			// usually false: `double(n: int)` has a parameter that is merely not
			// readable yet. The two cases get different words because they are
			// different facts. See SPEC-TUI-011, SPEC-MEM-022.
			fmt.sbprintln(&b, "    (no variables)")
		}
		for slot in frame.slots {
			write_slot(&b, slot, 4, s.style)
		}
		if frame.returned_text != "" {
			fmt.sbprintf(&b, "    returned %s\n", frame.returned_text)
		}
	}

	fmt.sbprintln(&b, "\nOBJECTS")
	if len(s.entities) == 0 {
		fmt.sbprintln(&b, "  (none)")
	}
	for e in s.entities {
		write_entity(&b, e, s.entities, s.style)
	}

	if len(step.truncations) > 0 {
		fmt.sbprintln(&b, "\nLIMITS REACHED AT THIS STEP")
		for t in step.truncations {
			fmt.sbprintf(&b, "  %s: showing at most %d\n", t.what, t.limit)
		}
	}

	fmt.sbprintf(&b, "\nOUTPUT SO FAR: %d bytes\n", step.stdout_len)
	return strings.to_string(b)
}

write_source :: proc(b: ^strings.Builder, s: Screen, current: int) {
	fmt.sbprintln(b, "CODE")
	first := max(1, current - s.context_lines)
	last := min(len(s.source), current + s.context_lines)
	for number in first ..= last {
		// The marker is a character, never colour alone. Colour that carries
		// meaning on its own is information lost in monochrome
		// (SPEC-TUI-042).
		marker := number == current ? (s.style.unicode ? "▸" : ">") : " "
		fmt.sbprintf(b, "  %s %3d %s\n", marker, number, s.source[number - 1])
	}
}

write_slot :: proc(b: ^strings.Builder, slot: tutor_model.Slot, indent: int, style: Style) {
	pad := strings.repeat(" ", indent, context.temp_allocator)
	if slot.state != .Valid {
		fmt.sbprintf(b, "%s%s %s", pad, slot.name, state_mark(slot.state, style))
		if slot.reason != "" {
			fmt.sbprintf(b, " (%s)", slot.reason)
		}
		fmt.sbprintln(b, "")
		return
	}
	if slot.refers_to != tutor_model.NO_ID {
		arrow := style.unicode ? "→" : "->"
		fmt.sbprintf(b, "%s%s %s %s\n", pad, slot.name, arrow, label(slot.refers_to, style))
		return
	}
	fmt.sbprintf(b, "%s%s = %s\n", pad, slot.name, slot.text)
}

write_entity :: proc(
	b: ^strings.Builder,
	e: tutor_model.Entity,
	all: []tutor_model.Entity,
	style: Style,
) {
	fmt.sbprintf(b, "  %s %s", label(e.id, style), e.type_name)
	if e.length > 0 {
		fmt.sbprintf(b, " (%d)", e.length)
	}
	if e.text != "" {
		fmt.sbprintf(b, " %s", e.text)
	}

	// Sharing is stated IN WORDS, and it names the other view.
	//
	// A repeated storage label alone would not do: a student does not know what
	// a storage label is until the interface says so. And aliasing must not
	// share this mark — two names for one object is not the same fact as two
	// windows onto one buffer, and collapsing them reintroduces the sub-slice
	// bug at the presentation layer. See SPEC-TUI-020.
	if e.shares_storage_with != tutor_model.NO_ID {
		other := first_sharer(e, all)
		if other != tutor_model.NO_ID {
			fmt.sbprintf(b, "   shares with %s", label(other, style))
		} else {
			fmt.sbprintf(b, "   shares storage %s", label(e.shares_storage_with, style))
		}
	}
	fmt.sbprintln(b, "")
	for m in e.members {
		write_slot(b, m, 6, style)
	}
}

// first_sharer finds another view on the same storage, so the note can name it.
//
// The lowest identity other than this one, so the naming is stable: a student
// watching "shares with ②" keeps reading the same sentence as long as both
// views live. See SPEC-TUI-003.
first_sharer :: proc(e: tutor_model.Entity, all: []tutor_model.Entity) -> tutor_model.Id {
	best := tutor_model.NO_ID
	for other in all {
		if other.id == e.id || other.shares_storage_with != e.shares_storage_with {
			continue
		}
		if best == tutor_model.NO_ID || other.id < best {
			best = other.id
		}
	}
	return best
}
