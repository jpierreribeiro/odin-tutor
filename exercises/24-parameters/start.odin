package main

import "core:fmt"

// `dobrar` must double the caller's variable, not a copy of it.
//
// Parameters arrive as copies, so `n := n` below doubles something that is
// thrown away when the procedure returns. Take a pointer instead — `n: ^int` —
// and write through it with `n^`.
dobrar :: proc(n: int) {
	n := n
	n *= 2
}

main :: proc() {
	total := 3
	dobrar(total)
	fmt.println(total)
}
