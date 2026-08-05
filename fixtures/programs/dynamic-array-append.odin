package main

import "core:fmt"

// Appending past the capacity moves the data to new storage. The dynamic
// array's own identity must survive that move; the storage identity must not.
// Conflating the two makes a growth look like the variable being replaced.
main :: proc() {
	numbers: [dynamic]int
	defer delete(numbers)
	append(&numbers, 10)
	append(&numbers, 20)
	append(&numbers, 30)
	fmt.println(numbers[:], len(numbers), cap(numbers))
}
