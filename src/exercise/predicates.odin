// Predicate evaluation over a trace.
//
// EVERY path that cannot find its subject produces `Undetermined`, never
// `Fail`. A name that does not exist may mean the student named it differently,
// and that is not evidence of a wrong picture (SPEC-VAL-020).
package tutor_exercise

import "core:fmt"
import "core:strconv"
import "core:strings"
import tutor_model "../model"

// Subject is what a path resolved to.
Subject :: struct {
	found:     bool,
	// entity is set when the path reached an object or a view.
	entity:    tutor_model.Entity,
	has_entity: bool,
	// text and state come from the slot itself.
	text:      string,
	state:     tutor_model.Value_State,
	refers_to: tutor_model.Id,
	is_reference: bool,
}

// resolve walks a path such as "main:head.next.next".
//
// The frame prefix names a procedure; without it the innermost student frame is
// used. Each `.` hop follows a reference into the entity's members.
resolve :: proc(
	step: tutor_model.Step,
	entities: []tutor_model.Entity,
	path: string,
) -> Subject {
	frame_name := ""
	rest := path
	if colon := strings.index_byte(path, ':'); colon >= 0 {
		frame_name = path[:colon]
		rest = path[colon + 1:]
	}

	frame_index := -1
	for frame, i in step.frames {
		if frame_name == "" {
			frame_index = i
			break
		}
		if strings.has_suffix(frame.procedure, frame_name) {
			frame_index = i
			break
		}
	}
	if frame_index < 0 {
		return {}
	}

	parts := hops(rest, context.temp_allocator)
	if len(parts) == 0 {
		return {}
	}

	subject: Subject
	found := false
	for slot in step.frames[frame_index].slots {
		if slot.name == parts[0] {
			subject = Subject {
				found        = true,
				text         = slot.text,
				state        = slot.state,
				refers_to    = slot.refers_to,
				is_reference = slot.is_reference,
			}
			found = true
			break
		}
	}
	if !found {
		return {}
	}

	for hop in parts[1:] {
		if subject.refers_to == tutor_model.NO_ID {
			return {}
		}
		target, has := entity_by_id(entities, subject.refers_to)
		if !has {
			return {}
		}
		next: Subject
		reached := false
		for member in target.members {
			if member.name == hop {
				next = Subject {
					found     = true,
					text      = member.text,
					state     = member.state,
					refers_to = member.refers_to,
					is_reference = member.is_reference,
				}
				reached = true
				break
			}
		}
		if !reached {
			return {}
		}
		subject = next
	}

	if subject.refers_to != tutor_model.NO_ID {
		if e, has := entity_by_id(entities, subject.refers_to); has {
			subject.entity = e
			subject.has_entity = true
		}
	}
	return subject
}

// hops splits a path into the steps a walk takes, so that `marks[2]` reaches
// the same member as `marks.[2]`.
//
// An element is ALREADY a member, named `[2]` by the adapter, and before this
// the only way to name one was to write that bracket after a dot — which nobody
// guesses. The vocabulary could count elements and compare lengths, and could
// not ask what the third element IS, so a whole class of exercise was
// unwritable: a loop that doubles in place, a sort that sorts the buffer it was
// given, an append that moved its storage.
//
//	marks[2]        -> ["marks", "[2]"]
//	casa.cantos[1]  -> ["casa", "cantos", "[1]"]
hops :: proc(path: string, allocator := context.temp_allocator) -> []string {
	out := make([dynamic]string, allocator)
	start := 0
	for i := 0; i < len(path); i += 1 {
		switch path[i] {
		case '.':
			if i > start {
				append(&out, path[start:i])
			}
			start = i + 1
		case '[':
			if i > start {
				append(&out, path[start:i])
			}
			closing := strings.index_byte(path[i:], ']')
			if closing < 0 {
				// An unbalanced bracket is an AUTHORING mistake, and the path
				// simply does not resolve — which reports `undetermined` with
				// the expression in it rather than guessing an index.
				return out[:]
			}
			append(&out, path[i:i + closing + 1])
			i += closing
			start = i + 1
		}
	}
	if start < len(path) {
		append(&out, path[start:])
	}
	return out[:]
}

entity_by_id :: proc(entities: []tutor_model.Entity, id: tutor_model.Id) -> (tutor_model.Entity, bool) {
	for e in entities {
		if e.id == id {
			return e, true
		}
	}
	return {}, false
}

// evaluate_one runs one assertion across the steps its selector chooses.
evaluate_one :: proc(
	assertion: Assertion,
	trace: tutor_model.Trace,
	allocator := context.allocator,
) -> Result {
	call, parsed := parse(assertion.expr)
	if !parsed {
		return Result {
			id = assertion.id,
			verdict = .Undetermined,
			reason = fmt.aprintf("the assertion could not be read: %s", assertion.expr, allocator = allocator),
		}
	}

	// A trace that was cut short cannot support "this never happened" or "this
	// always held". Both directions lose evidence (SPEC-VAL-010).
	truncated := trace.termination != .Completed
	for step in trace.steps {
		if len(step.truncations) > 0 {
			truncated = true
			break
		}
	}

	selector := assertion.at
	if selector == "" {
		selector = "final"
	}

	switch {
	case selector == "final":
		return at_step(call, trace, len(trace.steps) - 1, assertion.id, allocator)

	case selector == "any":
		for index in 0 ..< len(trace.steps) {
			r := at_step(call, trace, index, assertion.id, allocator)
			if r.verdict == .Pass {
				return r
			}
		}
		if truncated {
			// Not yet satisfied, and the trace stopped early. "It never
			// happened" is not something a cut-short trace can say.
			return undetermined(assertion.id, "the trace was cut short before this could be shown", allocator)
		}
		return Result{id = assertion.id, verdict = .Fail, reason = "no step satisfied this"}

	case selector == "all":
		seen := 0
		for index in 0 ..< len(trace.steps) {
			r := at_step(call, trace, index, assertion.id, allocator)
			if r.verdict == .Fail {
				return r
			}
			if r.verdict == .Pass {
				seen += 1
			}
		}
		if seen == 0 {
			return undetermined(assertion.id, "no step had the subjects this needs", allocator)
		}
		if truncated {
			return undetermined(assertion.id, "it held everywhere the trace reached, and the trace was cut short", allocator)
		}
		return Result{id = assertion.id, verdict = .Pass, step = seen}

	case strings.has_prefix(selector, "at_line("):
		wanted, ok := strconv.parse_int(strings.trim_suffix(selector[len("at_line("):], ")"))
		if !ok {
			return undetermined(assertion.id, "the selector could not be read", allocator)
		}
		for step, index in trace.steps {
			if step.line == wanted {
				return at_step(call, trace, index, assertion.id, allocator)
			}
		}
		// A line the program never reached is missing evidence, not a wrong
		// answer (SPEC-VAL-011).
		return undetermined(assertion.id, fmt.aprintf("the trace never reached line %d", wanted, allocator = allocator), allocator)

	case strings.has_prefix(selector, "on_return_of("):
		wanted := unquote(strings.trim_suffix(selector[len("on_return_of("):], ")"))
		for step, index in trace.steps {
			for frame in step.frames {
				if frame.returned_text != "" && strings.has_suffix(frame.procedure, wanted) {
					return at_step(call, trace, index, assertion.id, allocator)
				}
			}
		}
		return undetermined(assertion.id, fmt.aprintf("no return of %s was attributed", wanted, allocator = allocator), allocator)
	}

	return undetermined(assertion.id, fmt.aprintf("unknown selector: %s", selector, allocator = allocator), allocator)
}

undetermined :: proc(id, reason: string, allocator := context.allocator) -> Result {
	return Result{id = id, verdict = .Undetermined, reason = strings.clone(reason, allocator)}
}

// at_step evaluates one call at one step.
at_step :: proc(
	call: Call,
	trace: tutor_model.Trace,
	index: int,
	id: string,
	allocator := context.allocator,
) -> Result {
	if index < 0 || index >= len(trace.steps) {
		return undetermined(id, "the trace has no such step", allocator)
	}
	step := trace.steps[index]
	entities, ok := tutor_model.materialise(trace, index, context.temp_allocator)
	if !ok {
		return undetermined(id, "the step could not be reconstructed", allocator)
	}

	verdict, reason := apply(call, trace, step, entities)
	return Result{id = id, verdict = verdict, step = index + 1, reason = strings.clone(reason, allocator)}
}

// apply is the predicate table of VALIDATION-SPEC §4.
apply :: proc(
	call: Call,
	trace: tutor_model.Trace,
	step: tutor_model.Step,
	entities: []tutor_model.Entity,
) -> (Verdict, string) {
	// Predicates over the run as a whole, which need no path.
	switch call.name {
	case "output_equals":
		if len(call.arguments) != 1 {
			return .Undetermined, "output_equals takes one argument"
		}
		return verdict_of(trace.stdout == call.arguments[0]), "the program's output"
	case "output_contains":
		if len(call.arguments) != 1 {
			return .Undetermined, "output_contains takes one argument"
		}
		return verdict_of(strings.contains(trace.stdout, call.arguments[0])), "the program's output"
	case "exits_with":
		wanted, ok := strconv.parse_int(call.arguments[0] if len(call.arguments) > 0 else "")
		if !ok {
			return .Undetermined, "exits_with takes a number"
		}
		if trace.termination != .Completed {
			return .Undetermined, "the program did not exit normally"
		}
		return verdict_of(trace.exit_code == wanted), "the exit code"
	case "terminated_by":
		if trace.termination == .Target_Crashed {
			return verdict_of(strings.contains(trace.detail, call.arguments[0] if len(call.arguments) > 0 else "")), trace.detail
		}
		return .Fail, "the program was not terminated by a signal"
	case "object_count":
		wanted, ok := strconv.parse_int(call.arguments[0] if len(call.arguments) > 0 else "")
		if !ok {
			return .Undetermined, "object_count takes a number"
		}
		if len(step.truncations) > 0 {
			return .Undetermined, "a budget cut this step, so the count is a floor"
		}
		return verdict_of(len(entities) == wanted), "the step's object count"
	case "returns":
		if len(call.arguments) != 2 {
			return .Undetermined, "returns takes a procedure and a value"
		}
		for frame in step.frames {
			if strings.has_suffix(frame.procedure, call.arguments[0]) {
				if frame.returned_text == "" {
					// Withheld, not wrong. SPEC-MEM-061.
					return .Undetermined, "no return value was attributed to this invocation"
				}
				return verdict_of(frame.returned_text == call.arguments[1]), frame.returned_text
			}
		}
		return .Undetermined, "that procedure has no frame at this step"
	}

	// Everything else needs at least one path.
	if len(call.arguments) == 0 {
		return .Undetermined, "this predicate needs a path"
	}
	a := resolve(step, entities, call.arguments[0])
	if !a.found {
		return .Undetermined, fmt.tprintf("%s is not in scope here", call.arguments[0])
	}

	two :: proc(
		call: Call,
		step: tutor_model.Step,
		entities: []tutor_model.Entity,
	) -> (Subject, Subject, bool) {
		if len(call.arguments) != 2 {
			return {}, {}, false
		}
		x := resolve(step, entities, call.arguments[0])
		y := resolve(step, entities, call.arguments[1])
		return x, y, x.found && y.found
	}

	switch call.name {
	case "alias":
		x, y, ok := two(call, step, entities)
		if !ok {
			return .Undetermined, "both paths must resolve"
		}
		if x.refers_to == tutor_model.NO_ID || y.refers_to == tutor_model.NO_ID {
			return .Undetermined, "one of these is not a reference"
		}
		return verdict_of(x.refers_to == y.refers_to), "two names for one object"
	case "not_alias":
		x, y, ok := two(call, step, entities)
		if !ok {
			return .Undetermined, "both paths must resolve"
		}
		if x.refers_to == tutor_model.NO_ID || y.refers_to == tutor_model.NO_ID {
			return .Undetermined, "one of these is not a reference"
		}
		return verdict_of(x.refers_to != y.refers_to), "two different objects"
	case "shares_storage", "not_shares_storage", "distinct":
		x, y, ok := two(call, step, entities)
		if !ok {
			return .Undetermined, "both paths must resolve"
		}
		if !x.has_entity || !y.has_entity {
			return .Undetermined, "one of these is not an object"
		}
		// SPEC-VAL-021: aliasing and shared storage are separate relations, and
		// an exercise must say which it means. There is deliberately no
		// predicate meaning "related".
		shares := x.entity.shares_storage_with != tutor_model.NO_ID &&
			x.entity.shares_storage_with == y.entity.shares_storage_with
		switch call.name {
		case "shares_storage":
			return verdict_of(shares), "two windows on one buffer"
		case "not_shares_storage":
			return verdict_of(!shares), "separate buffers"
		case:
			return verdict_of(!shares && x.refers_to != y.refers_to), "neither the same object nor the same buffer"
		}
	case "is_reference":
		// SPEC-VAL-024. `p := &thing` and `thing` reach the same object and are
		// not the same variable. Without this an exercise cannot ask for an
		// allocation rather than a local, because every other predicate reads
		// the same on both.
		return verdict_of(a.is_reference), a.is_reference ? "a pointer" : "the object itself"
	case "is_nil":
		if a.refers_to != tutor_model.NO_ID {
			return .Fail, "it refers to an object"
		}
		return verdict_of(a.text == "nil"), a.text
	case "cycle":
		if len(call.arguments) != 2 {
			return .Undetermined, "cycle takes a path and a field name"
		}
		_, revisited := walk_chain(entities, a.refers_to, call.arguments[1])
		return verdict_of(revisited), "following the field returns to a visited object"
	case "chain_length":
		if len(call.arguments) != 3 {
			return .Undetermined, "chain_length takes a path, a field, and a count"
		}
		wanted, ok := strconv.parse_int(call.arguments[2])
		if !ok {
			return .Undetermined, "chain_length takes a number"
		}
		visited, revisited := walk_chain(entities, a.refers_to, call.arguments[1])
		if revisited {
			// SPEC-VAL-022: a cyclic chain stops when it revisits, and then
			// chain_length is `fail` while `cycle` is `pass`.
			return .Fail, "the chain is a cycle, so it has no length"
		}
		return verdict_of(visited == wanted), fmt.tprintf("%d distinct objects before nil", visited)
	case "length_of":
		if !a.has_entity {
			return .Undetermined, "this is not a view"
		}
		return compare_number(call, a.entity.length, "length")
	case "element_count", "field_count":
		if !a.has_entity {
			return .Undetermined, "this is not an object"
		}
		if len(step.truncations) > 0 {
			// SPEC-VAL-023: the recorded count is a floor, not the count.
			return .Undetermined, "a budget cut this step, so the count is a floor"
		}
		return compare_number(call, len(a.entity.members), "count")
	case "type_of":
		if !a.has_entity {
			return .Undetermined, "this is not an object"
		}
		return verdict_of(call.compares && a.entity.type_name == call.expected), a.entity.type_name
	case "value_of":
		if a.state != .Valid {
			// The state IS the answer, and it is not the student's doing.
			return .Undetermined, fmt.tprintf("the value is %v", a.state)
		}
		return verdict_of(call.compares && a.text == call.expected), a.text
	case "state_of":
		name := state_name(a.state)
		return verdict_of(call.compares && name == call.expected), name
	}

	return .Undetermined, fmt.tprintf("unknown predicate: %s", call.name)
}

compare_number :: proc(call: Call, actual: int, what: string) -> (Verdict, string) {
	if !call.compares {
		return .Undetermined, fmt.tprintf("%s needs a comparison", call.name)
	}
	wanted, ok := strconv.parse_int(call.expected)
	if !ok {
		return .Undetermined, "the expected value is not a number"
	}
	return verdict_of(actual == wanted), fmt.tprintf("%s is %d", what, actual)
}

// walk_chain follows a field, stopping when it revisits an identity.
//
// The visited set is what makes a cyclic structure terminate here as well as in
// the model (REQ-MEM-011).
walk_chain :: proc(
	entities: []tutor_model.Entity,
	start: tutor_model.Id,
	field: string,
) -> (
	visited: int,
	revisited: bool,
) {
	seen := make(map[tutor_model.Id]bool, context.temp_allocator)
	current := start
	for current != tutor_model.NO_ID {
		if current in seen {
			return visited, true
		}
		seen[current] = true
		visited += 1
		entity, has := entity_by_id(entities, current)
		if !has {
			return visited, false
		}
		next := tutor_model.NO_ID
		for member in entity.members {
			if member.name == field {
				next = member.refers_to
				break
			}
		}
		current = next
	}
	return visited, false
}

state_name :: proc(state: tutor_model.Value_State) -> string {
	switch state {
	case .Valid:
		return "valid"
	case .Not_Yet_Active:
		return "not-yet-active"
	case .Unreadable:
		return "unreadable"
	case .Unknown:
		return "unknown"
	}
	return "unknown"
}

verdict_of :: proc(condition: bool) -> Verdict {
	return condition ? .Pass : .Fail
}
