// The course: discovery, ordering, and progress.
//
// This is the layer that turns a validator into something a student uses. It
// was missing for a while, and the way it went missing is worth recording: the
// Phase 5 acceptance criteria ask that every reference solution pass, that every
// exercise reject a wrong solution, that a truncated trace be undetermined, and
// that no reference reach a budget. All four passed while there was no way for a
// student to start.
//
// Passing tests hid a missing goal, in the one layer the project's rules did not
// cover. EXERCISE-SPEC.md §3 described this loop all along.
package tutor_exercise

import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

// Entry is one exercise found on disk.
Entry :: struct {
	directory: string,
	exercise:  Exercise,
	done:      bool,
}

// Progress is what the student has finished.
//
// Keyed by exercise id, never by directory order: an id is stable and a
// directory name changes when someone renames a file (SPEC-EX-011).
Progress :: struct {
	completed: []string `json:"completed"`,
}

// progress_path is outside the exercise tree.
//
// A student's progress is not part of the course content, and writing it beside
// the exercises would put their state into whatever they cloned.
progress_path :: proc(allocator := context.allocator) -> string {
	if state := os.get_env("XDG_STATE_HOME", context.temp_allocator); state != "" {
		return strings.concatenate({state, "/odin-tutor/progress.json"}, allocator)
	}
	home := os.get_env("HOME", context.temp_allocator)
	return strings.concatenate({home, "/.local/state/odin-tutor/progress.json"}, allocator)
}

progress_load :: proc(allocator := context.allocator) -> Progress {
	data, err := os.read_entire_file(progress_path(context.temp_allocator), context.temp_allocator)
	if err != nil {
		return {}
	}
	progress: Progress
	if json.unmarshal(data, &progress, allocator = allocator) != nil {
		// Unreadable progress is not a reason to refuse to teach. The student
		// starts from the beginning, which is recoverable; refusing to run is
		// not.
		return {}
	}
	return progress
}

progress_mark :: proc(progress: ^Progress, id: string, allocator := context.allocator) {
	for existing in progress.completed {
		if existing == id {
			return
		}
	}
	updated := make([dynamic]string, allocator)
	for existing in progress.completed {
		append(&updated, existing)
	}
	append(&updated, strings.clone(id, allocator))
	progress.completed = updated[:]
}

progress_save :: proc(progress: Progress) -> bool {
	path := progress_path(context.temp_allocator)
	directory := filepath.dir(path)
	if os.make_directory_all(directory) != nil && !os.exists(directory) {
		return false
	}
	data, err := json.marshal(progress, allocator = context.temp_allocator)
	if err != nil {
		return false
	}
	return os.write_entire_file(path, data) == nil
}

is_done :: proc(progress: Progress, id: string) -> bool {
	for existing in progress.completed {
		if existing == id {
			return true
		}
	}
	return false
}

// discover reads every exercise under a directory, in order.
//
// Ordered by `id`, not by the file system. Directory order changes when a file
// is renamed; an id does not (SPEC-EX-011).
discover :: proc(root: string, allocator := context.allocator) -> []Entry {
	entries := make([dynamic]Entry, allocator)

	handle, open_err := os.open(root)
	if open_err != nil {
		return entries[:]
	}
	defer os.close(handle)

	infos, read_err := os.read_directory(handle, -1, context.temp_allocator)
	if read_err != nil {
		return entries[:]
	}

	progress := progress_load(allocator)
	for info in infos {
		if info.type != .Directory {
			continue
		}
		manifest, join_err := filepath.join(
			{root, info.name, "exercise.json"}, context.temp_allocator,
		)
		if join_err != nil {
			continue
		}
		data, data_err := os.read_entire_file(manifest, context.temp_allocator)
		if data_err != nil {
			continue
		}
		exercise, load_err := load(data, allocator)
		if load_err != .None {
			continue
		}
		directory, dir_err := filepath.join({root, info.name}, allocator)
		if dir_err != nil {
			continue
		}
		append(&entries, Entry {
			directory = directory,
			exercise = exercise,
			done = is_done(progress, exercise.id),
		})
	}

	slice.sort_by(entries[:], proc(a, b: Entry) -> bool {
		return a.exercise.id < b.exercise.id
	})
	return entries[:]
}

// next_unfinished is where `odin-tutor` with no arguments starts.
//
// The student never types an exercise name. That is the difference between a
// validator and a course.
next_unfinished :: proc(entries: []Entry) -> (Entry, bool) {
	for entry in entries {
		if !entry.done {
			return entry, true
		}
	}
	return {}, false
}

// missing_requirements names the exercises this one says to do first.
//
// A WARNING, never a refusal. `requires` is advisory (SPEC-EX-010): a student
// who wants to jump ahead is not doing something wrong, and a course that
// refuses them is a course that argues with them.
missing_requirements :: proc(
	entry: Entry,
	progress: Progress,
	allocator := context.allocator,
) -> []string {
	missing := make([dynamic]string, allocator)
	for required in entry.exercise.requires {
		if !is_done(progress, required) {
			append(&missing, required)
		}
	}
	return missing[:]
}
