package main

import "core:fmt"

// `parte` must be a WINDOW onto `todos`, not a copy of part of it.
//
// The printed output is the same either way. That is the point of this
// exercise: the output cannot tell you which one you built, and the picture
// can.
main :: proc() {
	todos := []int{1, 2, 3}
	parte := []int{2, 3}
	fmt.println(len(todos), len(parte))
}
