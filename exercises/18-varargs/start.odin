package main

import "core:fmt"

// `total` must accept ANY NUMBER of integers, not exactly three.
//
// Odin writes that as `nums: ..int`, and inside the procedure `nums` is an
// ordinary slice: it has a length, and you can loop over it.
total :: proc(a: int, b: int, c: int) -> int {
	return a + b + c
}

main :: proc() {
	answer := total(1, 2, 3)
	fmt.println(answer)
}
