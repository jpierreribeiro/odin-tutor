package main

import "core:fmt"

main :: proc() {
	texto := "abc"
	visto := texto
	fmt.println(len(texto), len(visto))
}
