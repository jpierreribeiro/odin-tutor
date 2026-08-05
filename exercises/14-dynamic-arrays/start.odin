package main

import "core:fmt"

// Append three numbers to `numbers`.
main :: proc() {
	numbers: [dynamic]int
	defer delete(numbers)
	fmt.println(len(numbers))
}
