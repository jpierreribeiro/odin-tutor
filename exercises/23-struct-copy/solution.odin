package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

main :: proc() {
	a := Ponto{x = 1, y = 2}
	b := a
	b.x = 9
	fmt.println(a.x, b.x)
}
