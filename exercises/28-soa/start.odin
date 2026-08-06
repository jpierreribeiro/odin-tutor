package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

// `pontos` must be a STRUCTURE OF ARRAYS: one array of every `x`, one array of
// every `y`, instead of two whole points laid end to end.
//
// Odin writes that as `#soa[2]Ponto`, and everything you already know still
// works — `pontos[0].x` reads the same as before. Only the arrangement in
// memory changes, which is exactly what this exercise is about.
main :: proc() {
	pontos: [2]Ponto
	pontos[0].x = 1
	pontos[1].x = 2
	fmt.println(pontos[0].x, pontos[1].x)
}
