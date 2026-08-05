package main

import "core:fmt"

// THE LIE THIS PREVENTS: a display budget changing an identity.
//
// The array holds 40 elements at one step, past elements = 30 (SAFETY.md §4),
// so that step is truncated. It then holds 5 again. The identity must be equal
// before and after the truncated step.
//
// Measured: resizing down keeps the same data pointer, so the storage really is
// continuous across the truncated step and the assertion has something to hold.
//
// ADR-011: absence of evidence is not evidence of death. A budget stopped the
// tool from LOOKING; it did not mean the object stopped existing
// (SPEC-MEM-044).
main :: proc() {
	numbers: [dynamic]int
	defer delete(numbers)
	for i in 0 ..< 40 {
		append(&numbers, i)
	}
	full_length := len(numbers)
	resize(&numbers, 5)
	short_length := len(numbers)
	fmt.println(full_length, short_length, numbers[:])
}
