package main

import "core:fmt"

// The loop below adds the arrays element by element, and stops one short.
//
// Odin does not need the loop at all: `a + b` on two fixed arrays of the same
// type adds every element at once. Write that instead, and the whole class of
// off-by-one disappears with the loop.
main :: proc() {
	a := [3]int{1, 2, 3}
	b := [3]int{10, 20, 30}

	soma: [3]int
	for i in 0 ..< len(a) - 1 {
		soma[i] = a[i] + b[i]
	}
	fmt.println(soma[0], soma[1])
}
