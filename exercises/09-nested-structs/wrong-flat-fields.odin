package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

// Prints `3 4`, exactly like the reference solution.
//
// `Ponto` is declared and never used. The two numbers sit loose in `Casa`, held
// together only by their names, and nothing in the type says they are one
// point. The picture shows three flat fields instead of a struct holding a
// struct.
Casa :: struct {
	canto_x: int,
	canto_y: int,
	lado:    int,
}

main :: proc() {
	casa := Casa{canto_x = 3, canto_y = 4, lado = 10}
	fmt.println(casa.canto_x, casa.canto_y)
}
