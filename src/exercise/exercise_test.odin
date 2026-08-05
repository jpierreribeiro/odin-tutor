package tutor_exercise

import "core:testing"

@(test)
undetermined_is_never_a_pass :: proc(t: ^testing.T) {
	// SPEC-VAL-002. An exercise passes only when EVERY assertion passes, and
	// `undetermined` blocks it. Counting it as a pass would let the tool's own
	// limits award the exercise.
	testing.expect(t, !passed({{id = "A1", verdict = .Undetermined}}), "undetermined alone is not a pass")
	testing.expect(t, !passed({{id = "A1", verdict = .Pass}, {id = "A2", verdict = .Undetermined}}), "one undetermined blocks the pass")
	testing.expect(t, !passed({}), "an exercise with no assertions passes nothing")
	testing.expect(t, passed({{id = "A1", verdict = .Pass}}), "all passing is a pass")
}

@(test)
an_expression_is_parsed_into_a_call :: proc(t: ^testing.T) {
	call, ok := parse(`shares_storage("todos", "parte")`)
	testing.expect(t, ok, "a two-argument call parses")
	testing.expect_value(t, call.name, "shares_storage")
	testing.expect_value(t, len(call.arguments), 2)
	testing.expect_value(t, call.arguments[0], "todos")
	testing.expect_value(t, call.arguments[1], "parte")
	testing.expect(t, !call.compares, "there is no comparison here")
}

@(test)
a_comparison_is_separated_from_its_call :: proc(t: ^testing.T) {
	call, ok := parse(`length_of("parte") == 2`)
	testing.expect(t, ok, "a comparison parses")
	testing.expect_value(t, call.name, "length_of")
	testing.expect(t, call.compares, "the comparison is recorded")
	testing.expect_value(t, call.expected, "2")
}

@(test)
an_escaped_newline_survives_two_levels_of_quoting :: proc(t: ^testing.T) {
	// JSON decodes one level; the expression carries another. An output
	// assertion that lost its newline would compare against text no program
	// ever prints.
	call, ok := parse(`output_equals("3 2\n")`)
	testing.expect(t, ok, "the call parses")
	testing.expect_value(t, call.arguments[0], "3 2\n")
}

@(test)
a_malformed_expression_is_refused_rather_than_guessed :: proc(t: ^testing.T) {
	// An exercise that cannot be read is an AUTHORING defect. Reporting it as
	// missing evidence would hide it behind the student's program.
	_, ok := parse("this is not a call")
	testing.expect(t, !ok, "a bare sentence is not an expression")
}
