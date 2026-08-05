package tutor_toolchain

import "core:strings"
import "core:testing"

@(test)
a_cache_key_changes_when_the_toolchain_changes :: proc(t: ^testing.T) {
	// THE TRAP THIS CLOSES. The trace's correctness depends on the debug
	// information a specific compiler version emits, so an executable built by
	// another Odin is a different executable even when the source is
	// byte-identical. Reusing it would draw a picture from one toolchain while
	// the tool reports another, and nothing would look wrong.
	// See SPEC-PLAT-030, AGENT-GUIDE §6.
	source := transmute([]byte)string("package main\nmain :: proc() {}\n")

	first := cache_key(source, "dev-2026-07-nightly:819fdc7", context.temp_allocator)
	second := cache_key(source, "dev-2026-08:9caff63", context.temp_allocator)

	testing.expect(t, first != second, "the same source under two compilers is two keys")
}

@(test)
a_cache_key_changes_when_the_source_changes :: proc(t: ^testing.T) {
	version := "dev-2026-08:9caff63"
	first := cache_key(transmute([]byte)string("x := 1"), version, context.temp_allocator)
	second := cache_key(transmute([]byte)string("x := 2"), version, context.temp_allocator)
	testing.expect(t, first != second, "one edited character is a different program")
}

@(test)
a_cache_key_is_the_same_for_the_same_inputs :: proc(t: ^testing.T) {
	// Without this the cache never hits, and compilation dominates the loop the
	// student edits in: 0.98 s to compile against 0.4 s to trace 300 steps.
	source := transmute([]byte)string("package main")
	first := cache_key(source, "dev-2026-08", context.temp_allocator)
	second := cache_key(source, "dev-2026-08", context.temp_allocator)
	testing.expect_value(t, first, second)
}

@(test)
every_failure_explains_itself :: proc(t: ^testing.T) {
	// REQ-ERR-001: a failure produces a named error and an instruction, never a
	// bare enum name the student has to search for. A new Failure member with no
	// sentence fails here rather than reaching a student.
	for failure in Failure {
		text := explain(failure, context.temp_allocator)
		if failure == .None {
			testing.expect_value(t, text, "")
			continue
		}
		testing.expect(t, len(text) > 0, "every failure has a sentence")
		testing.expect(
			t,
			strings.contains(text, ":"),
			"the sentence starts with a named code, as in TOOLCHAIN_MISSING:",
		)
		testing.expect(t, text != "Unknown failure.", "the sentence is not the fallback")
	}
}

@(test)
the_first_line_of_a_version_string_is_taken :: proc(t: ^testing.T) {
	// `gdb --version` prints a paragraph. The compatibility matrix matches on a
	// prefix of the first line, so the rest would only make the match fail.
	multi := "GNU gdb (Ubuntu 15.1) 15.1\nCopyright (C) 2024\nLicense GPLv3+\n"
	testing.expect_value(t, first_line(multi), "GNU gdb (Ubuntu 15.1) 15.1")
	testing.expect_value(t, first_line("no newline at all"), "no newline at all")
	testing.expect_value(t, first_line(""), "")
}

@(test)
the_cache_never_lives_in_the_students_directory :: proc(t: ^testing.T) {
	// ROADMAP Phase 1, acceptance 6: a full run leaves every student-authored
	// file byte-identical. The surest way to keep that true is to write nothing
	// into their directory at all, so the cache path must be absolute and
	// somewhere else.
	root := cache_root(context.temp_allocator)
	testing.expect(t, len(root) > 0, "a cache root is always produced")
	testing.expect(t, strings.has_prefix(root, "/"), "the cache root is an absolute path")
	testing.expect(
		t,
		strings.has_suffix(root, "/odin-tutor"),
		"the cache is namespaced, so it never shares a directory with anything else",
	)
}
