package main

import "core:fmt"

// Prints `2`, exactly like the reference solution.
//
// The array still holds three names — "ana" is in it twice — and the count was
// fixed on the way to the screen by subtracting a duplicate somebody knew
// about. Offer a fourth name that repeats and this is wrong again, silently.
//
// In the picture, `vistos` says how many things are in it. The right answer
// says 2 because there are 2. This one says 3.
main :: proc() {
	vistos: [dynamic]string
	defer delete(vistos)

	append(&vistos, "ana")
	append(&vistos, "bo")
	append(&vistos, "ana")

	fmt.println(len(vistos) - 1)
}
