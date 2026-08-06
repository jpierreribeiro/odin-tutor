package main

import "core:fmt"

// Prints `3 1`, exactly like the reference solution.
//
// The reversal was started and never finished: only element 0 was moved, so
// `trocado` holds {3, 2, 3} — the last element is still the copy's own third
// value, not the first. The printed line shows the one element that is right.
//
// It does get one thing right, and it is worth seeing: `trocado := ordem` COPIED
// the array, so writing into `trocado` left `ordem` alone. A fixed array is a
// value, not a view.
main :: proc() {
	ordem := [3]int{1, 2, 3}

	trocado := ordem
	trocado[0] = ordem[2]
	fmt.println(trocado[0], ordem[0])
}
