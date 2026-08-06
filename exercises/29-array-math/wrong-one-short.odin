package main

import "core:fmt"

// Prints `11 22`, exactly like the reference solution.
//
// The loop stops one element short — `len(a) - 1` — so the third sum was never
// computed and `soma[2]` is still the zero the array was created with. Nothing
// printed here would ever tell you: the program only shows the two elements it
// got right.
//
// This is the bug the language removes. `a + b` has no index to be wrong about.
main :: proc() {
	a := [3]int{1, 2, 3}
	b := [3]int{10, 20, 30}

	soma: [3]int
	for i in 0 ..< len(a) - 1 {
		soma[i] = a[i] + b[i]
	}
	fmt.println(soma[0], soma[1])
}
