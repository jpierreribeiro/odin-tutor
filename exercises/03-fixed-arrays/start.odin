package main

import "core:fmt"

// Make `marks` a FIXED array of four ints: 7, 8, 9, 10.
//
// A fixed array and a slice print the same. They are not the same thing.
main :: proc() {
	marks := []int{7, 8, 9, 10}
	fmt.println(marks)
}
