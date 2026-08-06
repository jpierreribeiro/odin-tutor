package main

import "core:fmt"

Ponto :: struct {
	x: int,
	y: int,
}

main :: proc() {
	pontos: #soa[2]Ponto
	pontos[0].x = 1
	pontos[1].x = 2
	fmt.println(pontos[0].x, pontos[1].x)
}
