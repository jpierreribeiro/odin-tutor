package main

import "core:fmt"

Box :: struct {
	value: int,
}

main :: proc() {
	first := Box{value = 1}
	a := &first
	b := &first
	a.value = 42
	fmt.println(a.value, b.value)
}
