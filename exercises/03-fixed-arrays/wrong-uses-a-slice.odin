package main

import "core:fmt"

// A plausible wrong solution: a slice. It prints "[7, 8, 9, 10]", exactly like
// the reference.
//
// A slice is a pointer and a length pointing AT some storage, so two slices can
// share one buffer. A fixed array IS the storage, and its length is in its type
// where nothing can corrupt it. The printed line cannot tell you which you have.
main :: proc() {
	marks := []int{7, 8, 9, 10}
	fmt.println(marks)
}
