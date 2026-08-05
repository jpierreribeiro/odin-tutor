package main

import "core:fmt"

// Make `countdown` call itself, once per step, and return how many steps it
// took to reach zero.
countdown :: proc(n: int) -> int {
	return n
}

main :: proc() {
	steps := countdown(4)
	fmt.println(steps)
}
