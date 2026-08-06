package main

import "core:fmt"
import "core:strings"

// `visto` must be a SECOND VIEW of the same bytes, not a second set of them.
//
// `strings.clone` allocates new memory and copies every byte into it. Plain
// assignment does not: an Odin string is a pointer and a length, so copying the
// string copies those two numbers and leaves the bytes where they are.
//
// Make `visto` share `texto`'s bytes. The printed lengths do not change.
main :: proc() {
	texto := "abc"
	visto := strings.clone(texto)
	fmt.println(len(texto), len(visto))
}
