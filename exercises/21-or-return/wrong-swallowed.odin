package main

import "core:fmt"

Erro :: enum {
	None,
	Empty,
}

primeiro :: proc(xs: []int) -> (int, Erro) {
	if len(xs) == 0 {
		return 0, .Empty
	}
	return xs[0], .None
}

// The error is thrown away with `_`, and the zero that came with it is doubled
// and reported as a real answer with `.None` beside it.
//
// This is the shape of the mistake this whole project is about: a wrong answer
// that looks like an answer. The caller is told nothing went wrong, and the
// picture shows `err = None` at a step where the slice was empty.
dobro :: proc(xs: []int) -> (n: int, err: Erro) {
	v, _ := primeiro(xs)
	return v * 2, .None
}

main :: proc() {
	n, err := dobro({})
	fmt.println(n, err)
}
