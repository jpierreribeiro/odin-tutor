package main

import "core:fmt"

// A plausible wrong solution: a loop. It prints 4, exactly like the reference.
//
// There is only ever ONE frame. The recursive version reaches a frame holding
// n = 0 that returns 0, and this one never does — that base case is what the
// exercise is about, and the printed number cannot see it.
countdown :: proc(n: int) -> int {
	n := n
	steps := 0
	for n > 0 {
		n -= 1
		steps += 1
	}
	return steps
}

main :: proc() {
	steps := countdown(4)
	fmt.println(steps)
}
