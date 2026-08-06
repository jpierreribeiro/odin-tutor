package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

// Prints `1 2`, exactly like the reference solution, and reads identically in
// the source: `pontos[0].x` either way. That is the whole promise of #soa —
// the code does not change.
//
// The MEMORY changes, and only the picture shows it. Here you get two whole
// points in a row: x, y, x, y. The reference gets two arrays: all the x
// together, all the y together — which is what makes touching every x cheap and
// what a data-oriented design is about.
main :: proc() {
	pontos: [2]Ponto
	pontos[0].x = 1
	pontos[1].x = 2
	fmt.println(pontos[0].x, pontos[1].x)
}
