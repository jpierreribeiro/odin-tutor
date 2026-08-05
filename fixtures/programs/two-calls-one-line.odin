package main

import "core:fmt"

double :: proc(n: int) -> int {
	return n * 2
}

// THE LIE THIS PREVENTS: one frame identity for two invocations.
//
// Both calls sit on one source line, so a frame key built from the source
// position alone merges them, and one invocation's values are shown under the
// other's frame.
//
// Measured 2026-08-05: the two call sites produce two distinct return
// addresses, so the caller's (pc, sp) separates them (SPEC-MEM-060).
main :: proc() {
	total := double(1) + double(2)
	fmt.println(total)
}
