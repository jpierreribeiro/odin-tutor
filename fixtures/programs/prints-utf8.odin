package main

import "core:fmt"

// SPEC-TEST-030: this fixture is NOT OPTIONAL.
//
// It exists to catch a unit mismatch between a character count and a byte
// limit. "naïve ✓" is 7 characters and 10 bytes: the ï costs two bytes and the
// ✓ costs three. Any text where the two counts differ does the job — the
// literal is chosen for that gap, not for its content.
//
// A prior system truncated on the character count against a byte limit, cut the
// document mid-way, and lost the entire trace instead of truncating it
// (SPEC-SAFE-031).
main :: proc() {
	text := "naïve ✓"
	bytes := len(text)
	fmt.println(text, bytes)
}
