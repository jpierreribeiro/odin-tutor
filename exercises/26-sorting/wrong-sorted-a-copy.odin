package main

import "core:fmt"
import "core:slice"

// Prints `1 4 9`, exactly like the reference solution.
//
// `nums` was never sorted. A second buffer was allocated, sorted, printed, and
// freed — so every later reader of `nums` still gets 9, 1, 4, and this line of
// the program is the only place that ever looked sorted.
//
// This is the sub-slice lesson again, from the other direction: whether two
// names share one buffer decides whether your work is visible to anybody else.
main :: proc() {
	nums := []int{9, 1, 4}
	copia := slice.clone(nums)
	defer delete(copia)
	slice.sort(copia)
	fmt.println(copia[0], copia[1], copia[2])
}
