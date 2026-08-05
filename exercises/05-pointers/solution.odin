package main

import "core:fmt"

Counter :: struct {
	value: int,
}

bump :: proc(c: ^Counter) {
	c.value = 9
}

main :: proc() {
	counter := Counter{value = 1}
	p := &counter
	bump(p)
	fmt.println(counter.value)
}
