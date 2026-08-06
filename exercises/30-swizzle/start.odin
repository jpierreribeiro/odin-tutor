package main

import "core:fmt"

// `trocado` must be `ordem` backwards, and `ordem` must be left alone.
//
// The reversal below is done by hand and only half written. Odin can name the
// order directly: `ordem.zyx` builds a new array whose elements are the third,
// the second and the first — and `.xyz`, `.rgba` are the same slots under names
// you may find easier to read.
main :: proc() {
	ordem := [3]int{1, 2, 3}

	trocado := ordem
	trocado[0] = ordem[2]
	fmt.println(trocado[0], ordem[0])
}
