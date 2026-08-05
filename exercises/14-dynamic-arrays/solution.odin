package main

import "core:fmt"

main :: proc() {
	numbers: [dynamic]int
	defer delete(numbers)
	append(&numbers, 1)
	append(&numbers, 2)
	append(&numbers, 3)
	fmt.println(len(numbers))
}
