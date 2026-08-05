package main

import "core:fmt"

Box :: struct {
	value: int,
}

// Make `a` and `b` name the SAME box, so setting one sets the other.
main :: proc() {
	first := Box{value = 1}
	second := Box{value = 1}
	a := &first
	b := &second
	a.value = 42
	fmt.println(a.value, b.value)
}
