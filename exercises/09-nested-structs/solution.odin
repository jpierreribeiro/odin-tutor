package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

Casa :: struct {
	canto: Ponto,
	lado:  int,
}

main :: proc() {
	casa := Casa{canto = Ponto{x = 3, y = 4}, lado = 10}
	fmt.println(casa.canto.x, casa.canto.y)
}
