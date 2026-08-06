// Where the student's copy of the course lives.
//
// Before this existed, the student edited the exercises inside the repository
// they had cloned. Their work and the course's history were the same tree: a
// `git pull` conflicted with their answers, and `git status` was never clean
// again. `odin-tutor init` copies the exercises into a directory of their own,
// and every path the loop uses is resolved from there.
//
// The rule this file follows: NOTHING is written into the course's own tree at
// any point, and nothing outside the directory the student named is created
// except the progress file, which was already outside it.
package tutor_exercise

import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:strings"

// STORE is the one hidden directory. It holds the marker, the progress, and the
// pristine copies — so a student can delete their course by deleting one tree,
// and can see everything the tool keeps by listing one directory.
STORE :: ".odin-tutor"
MARKER :: "course.json"
ORIGINALS :: "original"

// MAX_ASCENT bounds the walk towards the root.
//
// Bounded rather than "until /": an unbounded loop over a path is a loop over
// something a symlink can lengthen, and the answer at depth 40 is not one a
// student is waiting for anyway.
MAX_ASCENT :: 40

// Marker is what `init` writes, and the only thing that makes a directory a
// course. Its presence is the question; the contents are for a human reading it.
Marker :: struct {
	version:   int    `json:"version"`,
	source:    string `json:"source"`,
	exercises: int    `json:"exercises"`,
}

MARKER_VERSION :: 1

// Course is every path the loop needs, resolved once.
//
// `root` is empty when the tool is run from the repository rather than from a
// student's directory. That case still works — a contributor running the loop
// from the checkout is exactly how the exercises get written — but it is the
// case where `x:reset` has nothing to restore from, and this struct says so
// rather than the loop discovering it late.
Course :: struct {
	root:      string,
	exercises: string,
	state:     string,
	originals: string,
}

// student reports whether this course was made by `init`.
student :: proc(c: Course) -> bool {
	return c.root != ""
}

// locate answers "which course am I in?" by walking towards the root.
//
// The working directory is consulted HERE and nowhere else. Everything
// downstream takes a Course, so a test can name its own paths and no procedure
// has to guess where the student is standing.
locate :: proc(allocator := context.allocator) -> Course {
	working, err := os.get_working_directory(context.temp_allocator)
	if err == nil {
		// `filepath.dir` returns a SLICE of its input, so this walk allocates
		// nothing and must not free anything. See the note in cmd_play's
		// source_beside for the segfault that taught us this.
		directory := working
		for _ in 0 ..< MAX_ASCENT {
			marker, join_err := filepath.join(
				{directory, STORE, MARKER}, context.temp_allocator,
			)
			if join_err == nil && os.exists(marker) {
				return course_at(directory, allocator)
			}
			parent := filepath.dir(directory)
			if parent == directory {
				break
			}
			directory = parent
		}
	}

	// The repository layout: exercises beside the working directory, progress in
	// the state directory it has always been in.
	return Course{exercises = "exercises", state = xdg_progress_path(allocator)}
}

// course_at builds the paths of a student directory.
course_at :: proc(root: string, allocator := context.allocator) -> Course {
	course: Course
	course.root = strings.clone(root, allocator)
	course.exercises, _ = filepath.join({root, "exercises"}, allocator)
	course.state, _ = filepath.join({root, STORE, "progress.json"}, allocator)
	course.originals, _ = filepath.join({root, STORE, ORIGINALS}, allocator)
	return course
}

Create_Error :: enum {
	None,
	Occupied,
	No_Source,
	Unwritable,
}

explain_create :: proc(err: Create_Error, destination: string, allocator := context.temp_allocator) -> string {
	switch err {
	case .None:
		return ""
	case .Occupied:
		return strings.concatenate(
			{
				"OCCUPIED: ", destination,
				" already exists. Delete it, or name a directory that does not exist yet.\n",
				"Nothing was written, because overwriting it would overwrite your answers.",
			},
			allocator,
		)
	case .No_Source:
		return "NO_EXERCISES: no exercises were found to copy. Run `odin-tutor init` from " +
			"an installed build, or from the repository root where the exercises directory is."
	case .Unwritable:
		return strings.concatenate(
			{"UNWRITABLE: could not write inside ", destination, "."},
			allocator,
		)
	}
	return ""
}

// create copies the course into a directory of the student's own.
//
// What is copied is what a student needs: the manifest, the file they edit, the
// hints, and the reference solution — which is copied ON PURPOSE, because the
// loop points at it once an exercise passes and a pointer to a file that is not
// there is worse than no pointer. The wrong solutions are NOT copied: they are
// the acceptance script's counter-examples, and a directory of deliberately
// broken answers is confusing to read and pointless to open.
create :: proc(destination, source_root: string, allocator := context.allocator) -> Create_Error {
	if os.exists(destination) {
		return .Occupied
	}

	found := discover_at(source_root, context.temp_allocator)
	if len(found) == 0 {
		return .No_Source
	}

	if os.make_directory_all(destination) != nil && !os.exists(destination) {
		return .Unwritable
	}

	copied := 0
	for entry in found {
		name := filepath.base(entry.directory)
		target, target_err := filepath.join(
			{destination, "exercises", name}, context.temp_allocator,
		)
		pristine, pristine_err := filepath.join(
			{destination, STORE, ORIGINALS, name}, context.temp_allocator,
		)
		if target_err != nil || pristine_err != nil {
			return .Unwritable
		}
		if os.make_directory_all(target) != nil && !os.exists(target) {
			return .Unwritable
		}
		if os.make_directory_all(pristine) != nil && !os.exists(pristine) {
			return .Unwritable
		}

		for file in wanted_files(entry, context.temp_allocator) {
			if !copy_file(entry.directory, target, file) {
				return .Unwritable
			}
		}
		// The pristine copy of the file the student edits. `x:reset` restores
		// from here, which is why the store is hidden and why nothing in the
		// loop ever writes to it.
		if !copy_file(entry.directory, pristine, entry.exercise.entry) {
			return .Unwritable
		}
		copied += 1
	}

	marker_dir, marker_dir_err := filepath.join({destination, STORE}, context.temp_allocator)
	if marker_dir_err != nil {
		return .Unwritable
	}
	if os.make_directory_all(marker_dir) != nil && !os.exists(marker_dir) {
		return .Unwritable
	}
	marker_path, marker_err := filepath.join({marker_dir, MARKER}, context.temp_allocator)
	if marker_err != nil {
		return .Unwritable
	}
	data, encode_err := json.marshal(
		Marker{version = MARKER_VERSION, source = source_root, exercises = copied},
		{pretty = true},
		context.temp_allocator,
	)
	if encode_err != nil || os.write_entire_file(marker_path, data) != nil {
		return .Unwritable
	}
	return .None
}

// wanted_files is everything an exercise directory contributes to the copy.
//
// Named from the manifest rather than by copying the whole directory, so a file
// that ends up beside an exercise — an editor's backup, a build artefact, a
// wrong solution — never becomes part of what a student is handed.
wanted_files :: proc(entry: Entry, allocator := context.allocator) -> []string {
	files := make([dynamic]string, allocator)
	append(&files, "exercise.json")
	append(&files, entry.exercise.entry)
	append(&files, "solution.odin")
	for hint in entry.exercise.hints {
		append(&files, hint)
	}
	return files[:]
}

// copy_file copies one file if it is there. A missing optional file is not an
// error: `solution.odin` is named unconditionally above and an exercise without
// one is still a usable exercise.
copy_file :: proc(from_directory, to_directory, name: string) -> bool {
	source, source_err := filepath.join({from_directory, name}, context.temp_allocator)
	target, target_err := filepath.join({to_directory, name}, context.temp_allocator)
	if source_err != nil || target_err != nil {
		return false
	}
	data, read_err := os.read_entire_file(source, context.temp_allocator)
	if read_err != nil {
		return !os.exists(source)
	}
	return os.write_entire_file(target, data) == nil
}

Reset_Error :: enum {
	None,
	No_Original,
	Unwritable,
}

// reset puts the file the student edits back to the way it was handed to them.
//
// Only from the pristine store. The alternative — regenerating it, or telling
// the student to run `git checkout` — either invents content or asks them to
// know a tool the course never taught. When there is no store, this says so.
reset :: proc(course: Course, entry: Entry) -> Reset_Error {
	if course.originals == "" {
		return .No_Original
	}
	name := filepath.base(entry.directory)
	source, source_err := filepath.join(
		{course.originals, name, entry.exercise.entry}, context.temp_allocator,
	)
	if source_err != nil {
		return .No_Original
	}
	data, read_err := os.read_entire_file(source, context.temp_allocator)
	if read_err != nil {
		return .No_Original
	}
	target, target_err := filepath.join(
		{entry.directory, entry.exercise.entry}, context.temp_allocator,
	)
	if target_err != nil {
		return .Unwritable
	}
	return os.write_entire_file(target, data) == nil ? .None : .Unwritable
}
