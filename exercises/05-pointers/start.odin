package main

import "core:fmt"

Counter :: struct {
	value: int,
}

// Make `bump` change the counter that `main` holds, not a copy of it.
//
// A copy prints 1. A reference prints 9.
bump :: proc(c: Counter) {
	c := c
	c.value = 9
}

main :: proc() {
	counter := Counter{value = 1}
	bump(counter)
	fmt.println(counter.value)
}
