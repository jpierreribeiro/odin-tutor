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

// `dobro` throws the error away with `_` and doubles whatever came back.
//
// On an empty slice that is a zero it invented. Hand the failure back instead:
// `primeiro(xs) or_return` returns from `dobro` the moment the error is not
// nil, and gives you the value otherwise.
//
// (`or_return` needs the results to be named, which they already are.)
dobro :: proc(xs: []int) -> (n: int, err: Erro) {
	v, _ := primeiro(xs)
	return v * 2, .None
}

main :: proc() {
	n, err := dobro({})
	fmt.println(n, err)
}
