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

dobro :: proc(xs: []int) -> (n: int, err: Erro) {
	v := primeiro(xs) or_return
	return v * 2, .None
}

main :: proc() {
	n, err := dobro({})
	fmt.println(n, err)
}
