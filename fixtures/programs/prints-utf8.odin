package main

import "core:fmt"

// SPEC-TEST-030: this fixture is NOT OPTIONAL.
//
// It exists to catch a unit mismatch between a character count and a byte
// limit. The literal below is 9 characters and 13 bytes — the multi-byte text
// is the payload, so it stays as it is while the identifiers do not.
//
// A prior system truncated on the character count against a byte limit, cut the
// document mid-way, and lost the entire trace instead of truncating it
// (SPEC-SAFE-031).
main :: proc() {
	text := "coração ✓"
	bytes := len(text)
	fmt.println(text, bytes)
}
