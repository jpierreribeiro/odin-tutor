package main

import "core:fmt"

// A plausible wrong solution: the arithmetic stays in main. It prints 7, and
// `add` is never called, so there is no second frame and no return value to
// attribute to anything.
add :: proc(a: int, b: int) -> int {
	return a + b
}

main :: proc() {
	total := 3 + 4
	fmt.println(total)
}
