package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

// A `Casa` must HOLD a `Ponto`, not two loose numbers that mean one.
//
// Give `Casa` a field named `canto` of type `Ponto`, and keep `lado`. Then
// `casa.canto.x` is a path the picture can follow, and `x` stops being a number
// that only your naming says belongs with `y`.
Casa :: struct {
	canto_x: int,
	canto_y: int,
	lado:    int,
}

main :: proc() {
	casa := Casa{canto_x = 3, canto_y = 4, lado = 10}
	fmt.println(casa.canto_x, casa.canto_y)
}
