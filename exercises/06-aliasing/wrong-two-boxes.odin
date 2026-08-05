package main

import "core:fmt"

Box :: struct {
	value: int,
}

// A plausible wrong solution: set both by hand. It prints "42 42" — exactly
// what the reference prints — and the two names still point at two boxes.
main :: proc() {
	first := Box{value = 1}
	second := Box{value = 1}
	a := &first
	b := &second
	a.value = 42
	b.value = 42
	fmt.println(a.value, b.value)
}
