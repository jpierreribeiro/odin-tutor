package main

import "core:fmt"

// THE LIE THIS PREVENTS: claiming the tool detects use after free.
//
// Measured 2026-08-05, and it refuted the specification's assumption: a freed
// region stays mapped and reads back as a plausible integer, with no error at
// all. This run printed 5984131979051105568 where the specification expected an
// unreadable address.
//
// The test asserts that the value is shown as an ORDINARY value — not as
// `unreadable` — because asserting `unreadable` here would encode a detection
// the tool does not have.
//
// R-21. Reading cannot detect this. Phase 6 (allocator observation) is the only
// path, and until then the documentation must not imply otherwise.
main :: proc() {
	dead := new(int)
	dead^ = 5
	free(dead)
	after := dead^
	fmt.println(after)
}
