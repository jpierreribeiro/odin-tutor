package main

import "core:fmt"

// `vistos` must hold each name ONCE, however many times it is offered.
//
// The dynamic array below appends every time, so "ana" lands twice and the
// count is 3. A `map[string]bool` is keyed: writing a key you already have
// replaces it, and the count stays at the number of DISTINCT names.
//
// Use `make(map[string]bool)`, write with `vistos[nome] = true`, and count with
// `len(vistos)`.
main :: proc() {
	vistos: [dynamic]string
	defer delete(vistos)

	append(&vistos, "ana")
	append(&vistos, "bo")
	append(&vistos, "ana")

	fmt.println(len(vistos))
}
