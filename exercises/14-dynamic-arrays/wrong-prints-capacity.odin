package main

import "core:fmt"

// A plausible wrong solution: one append, then print the capacity. The
// allocator reserves room ahead, so this can print a number that looks right
// while the array holds one element.
main :: proc() {
	numbers: [dynamic]int
	defer delete(numbers)
	append(&numbers, 1)
	fmt.println(cap(numbers))
}
