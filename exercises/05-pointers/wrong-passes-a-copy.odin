package main

import "core:fmt"

Counter :: struct {
	value: int,
}

// A plausible wrong solution. It compiles, it runs, and the counter never
// changes: `c` is a copy, and 9 is written into memory nobody reads again.
bump :: proc(c: Counter) {
	c := c
	c.value = 9
}

main :: proc() {
	counter := Counter{value = 1}
	p := &counter
	bump(counter)
	fmt.println(counter.value)
	_ = p
}
