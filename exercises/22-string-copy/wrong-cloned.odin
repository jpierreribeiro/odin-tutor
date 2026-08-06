package main

import "core:fmt"
import "core:strings"

// Prints `3 3`, exactly like the reference solution.
//
// It also allocates a second copy of the bytes and never frees it. Nothing in
// the output says so. In the picture there are TWO string objects with no
// `shares with` between them, where the right answer has one set of bytes seen
// twice.
main :: proc() {
	texto := "abc"
	visto := strings.clone(texto)
	fmt.println(len(texto), len(visto))
}
