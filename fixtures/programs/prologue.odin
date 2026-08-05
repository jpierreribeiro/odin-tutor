package main

import "core:fmt"

add :: proc(a: int, b: int) -> int {
	sum := a + b
	return sum
}

// THE LIE THIS PREVENTS: reading an argument at the procedure's signature line,
// before the prologue has run, and reporting stack garbage as its value.
//
// Phase 1 caught this live, twice: once for a local read before its declaring
// line, once for an argument read at the signature line. Both are now tests.
//
// SPEC-MEM-020: the state is `not-yet-active`, and the renderer must NOT print
// "no variables" — that tells the student the frame is empty, which is a
// different and false statement.
main :: proc() {
	result := add(3, 4)
	fmt.println(result)
}
