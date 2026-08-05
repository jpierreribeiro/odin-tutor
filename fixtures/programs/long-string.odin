package main

import "core:fmt"
import "core:strings"

// 400 bytes, past string_length = 256 (SAFETY.md §4).
//
// The budget and the limit it protects use the same unit, and the unit is in
// the name. SPEC-SAFE-031 records a prior system that counted characters
// against a byte limit: any text outside ASCII pushed the document past the
// limit, it was cut mid-document, and the whole trace was lost rather than
// truncated.
main :: proc() {
	long := strings.repeat("abcdefghij", 40)
	defer delete(long)
	length := len(long)
	fmt.println(length)
}
