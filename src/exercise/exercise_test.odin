package tutor_exercise

import "core:os"
import "core:path/filepath"
import "core:strings"
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

// --- the student's own copy of the course ------------------------------------

// Each test lays out its own tree under its OWN top-level directory.
//
// Not a shared parent with per-test subdirectories, which is what this was
// first: the runner is threaded, and two tests calling make_directory_all on
// the same missing parent race on creating it. One of them loses, its write
// lands nowhere, and the failure arrives later as an exercise whose hint file
// is empty.
@(private = "file")
SCRATCH :: "/tmp/odin-tutor-test"

@(private = "file")
write :: proc(t: ^testing.T, directory, name, contents: string) {
	// CHECKED, not discarded. A helper that ignores whether it wrote anything
	// reports a missing file as a wrong file, which is how the race above cost
	// an afternoon.
	err := os.make_directory_all(directory)
	testing.expect(t, err == nil || os.exists(directory), "the test could not make its own directory")
	path, join_err := filepath.join({directory, name}, context.temp_allocator)
	testing.expect(t, join_err == nil, "the test could not build its own path")
	testing.expect(
		t,
		os.write_entire_file(path, transmute([]byte)contents) == nil,
		"the test could not write its own fixture",
	)
}

@(private = "file")
read :: proc(parts: []string) -> string {
	path, _ := filepath.join(parts, context.temp_allocator)
	data, err := os.read_entire_file(path, context.temp_allocator)
	return err == nil ? string(data) : ""
}

@(private = "file")
MANIFEST :: `{"id":"01-values","title":"t","objective":"o","concepts":[],"difficulty":1,
"entry":"start.odin","hints":["hints.md"],
"assertions":[{"id":"A1","at":"any","expr":"value_of(\"x\") == \"1\""}]}`

@(private = "file")
lay_out_a_source_course :: proc(t: ^testing.T, name: string) -> (source: string, destination: string) {
	scratch := strings.concatenate({SCRATCH, "-", name}, context.temp_allocator)
	_ = os.remove_all(scratch)
	source, _ = filepath.join({scratch, "course", "exercises", "01-values"}, context.temp_allocator)
	write(t, source, "exercise.json", MANIFEST)
	write(t, source, "start.odin", "package main\n// TODO\n")
	write(t, source, "solution.odin", "package main\n// the answer\n")
	write(t, source, "hints.md", "a hint\n")
	// A counter-example, which belongs to the acceptance script and not to the
	// student.
	write(t, source, "wrong-off-by-one.odin", "package main\n// wrong\n")
	root, _ := filepath.join({scratch, "course", "exercises"}, context.temp_allocator)
	mine, _ := filepath.join({scratch, "mine"}, context.temp_allocator)
	return root, mine
}

@(test)
init_hands_the_student_a_copy_and_keeps_the_counter_examples :: proc(t: ^testing.T) {
	// The whole point of `init`: the student's answers and the course's own
	// tree stop being the same files. What they get is what they need — the
	// manifest, the file they edit, the hints, and the reference solution the
	// loop points at when they pass. Not the wrong solutions: a directory of
	// deliberately broken answers is confusing to read and pointless to open.
	source, destination := lay_out_a_source_course(t, "handed-over")

	testing.expect_value(t, create(destination, source, context.temp_allocator), Create_Error.None)
	testing.expect_value(t, read({destination, "exercises", "01-values", "start.odin"}), "package main\n// TODO\n")
	testing.expect_value(t, read({destination, "exercises", "01-values", "solution.odin"}), "package main\n// the answer\n")
	testing.expect_value(t, read({destination, "exercises", "01-values", "hints.md"}), "a hint\n")

	wrong, _ := filepath.join(
		{destination, "exercises", "01-values", "wrong-off-by-one.odin"}, context.temp_allocator,
	)
	testing.expect(t, !os.exists(wrong), "a wrong solution is not part of what a student is handed")
}

@(test)
init_refuses_a_directory_that_already_exists :: proc(t: ^testing.T) {
	// Overwriting it would overwrite the answers of whoever ran init first.
	// Nothing is written, and the refusal says which directory it is about.
	source, destination := lay_out_a_source_course(t, "occupied")
	testing.expect_value(t, create(destination, source, context.temp_allocator), Create_Error.None)
	testing.expect_value(t, create(destination, source, context.temp_allocator), Create_Error.Occupied)
	testing.expect(
		t,
		strings.contains(explain_create(.Occupied, destination, context.temp_allocator), destination),
		"the refusal names the directory it is refusing to touch",
	)
}

@(test)
reset_restores_the_file_from_a_copy_the_student_never_edits :: proc(t: ^testing.T) {
	// `x` has to work after any edit at all, including one that deleted the
	// file's contents, so it cannot be derived from what is on disk.
	source, destination := lay_out_a_source_course(t, "reset")
	testing.expect_value(t, create(destination, source, context.temp_allocator), Create_Error.None)

	course := course_at(destination, context.temp_allocator)
	entries := discover(course, context.temp_allocator)
	testing.expect_value(t, len(entries), 1)

	write(t, entries[0].directory, "start.odin", "package main\n// ruined\n")
	testing.expect_value(t, reset(course, entries[0]), Reset_Error.None)
	testing.expect_value(t, read({destination, "exercises", "01-values", "start.odin"}), "package main\n// TODO\n")
}

@(test)
a_course_without_a_pristine_copy_says_so_instead_of_guessing :: proc(t: ^testing.T) {
	// Running the loop from the repository is how the exercises get written,
	// and there `x` has nothing to restore from. Inventing a starting file, or
	// telling the student to run `git checkout`, are both worse than saying it.
	source, _ := lay_out_a_source_course(t, "no-original")
	repository := Course{exercises = source, state = "/dev/null"}
	entries := discover(repository, context.temp_allocator)
	testing.expect_value(t, len(entries), 1)
	testing.expect_value(t, reset(repository, entries[0]), Reset_Error.No_Original)
}

@(test)
progress_belongs_to_the_students_own_course :: proc(t: ^testing.T) {
	// Two courses on one machine must not share a count. Before `init` the
	// progress file was a single path in the state directory, which is right
	// when there is one copy of the exercises and wrong as soon as there are two.
	first := course_at("/home/someone/odin-tutor", context.temp_allocator)
	second := course_at("/home/someone/second-go", context.temp_allocator)
	testing.expect(t, first.state != second.state, "each course counts its own progress")
	testing.expect(t, student(first), "a directory made by init is a student's course")
	testing.expect(
		t, !student(Course{exercises = "exercises", state = "/tmp/x"}),
		"and the repository layout is not",
	)
}
