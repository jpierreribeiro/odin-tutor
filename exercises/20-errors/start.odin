package main

import "core:fmt"

// `divide` must return TWO things: the answer, and whether there is one.
//
// Dividing by zero has no answer. Say so with the second value instead of
// returning a number that looks real.
divide :: proc(a: int, b: int) -> (int, bool) {
	return a / b, true
}

main :: proc() {
	result, ok := divide(8, 0)
	if ok {
		fmt.println(result)
	} else {
		fmt.println("cannot divide by zero")
	}
}
