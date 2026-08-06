package main

import "core:fmt"

// Prints `6`, exactly like the reference solution.
//
// `dobrar` still doubles a copy and still changes nothing. The `6` comes from
// the CALL SITE doubling the number again on its way to being printed, so the
// program is right by accident and `total` is still 3.
//
// The output cannot see that. The picture can: look at `total` in the frame.
dobrar :: proc(n: int) {
	n := n
	n *= 2
}

main :: proc() {
	total := 3
	dobrar(total)
	fmt.println(total * 2)
}
