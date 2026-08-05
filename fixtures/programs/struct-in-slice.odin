package main

import "core:fmt"

Point :: struct {
	x: int,
	y: int,
}

// Each element is an object with its own identity, and all of them live in the
// slice's one storage. Giving each element a storage of its own loses the fact
// that writing through one element is visible through the slice.
main :: proc() {
	points := []Point{{1, 2}, {3, 4}, {5, 6}}
	second := points[1]
	fmt.println(points, second.x)
}
