package main

import "core:fmt"

// The Odin runtime's bounds check panics and the target ends. The index is a
// variable so the check happens at run time, where the student will meet it.
//
// The tool reports the panic and keeps the steps before it. A partial trace is
// never presented as a complete one.
main :: proc() {
	xs := []int{1, 2, 3}
	i := 5
	out := xs[i]
	fmt.println(out)
}
