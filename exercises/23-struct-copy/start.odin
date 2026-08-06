package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

// `b` must be a POINT OF ITS OWN, so that changing it leaves `a` alone.
//
// Right now `b` is a pointer at `a`, so the two names reach one object and the
// change lands on both. Make `b` a copy instead — in Odin that is plain
// assignment, and it copies every field.
main :: proc() {
	a := Ponto{x = 1, y = 2}
	b := &a
	b.x = 9
	fmt.println(a.x, b.x)
}
