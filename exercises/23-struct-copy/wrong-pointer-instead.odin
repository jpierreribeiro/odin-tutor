package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

// A plausible wrong answer: `&a` reads like "b is that point", and it is — it
// is THE SAME point. One object with two names, so `b.x = 9` also changed `a`.
//
// This exercise could not be shipped until the tool drew that correctly. It
// used to show two separate objects holding equal values, which said the
// opposite of the truth. See R-25.
main :: proc() {
	a := Ponto{x = 1, y = 2}
	b := &a
	b.x = 9
	fmt.println(a.x, b.x)
}
