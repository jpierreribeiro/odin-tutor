package main

import "core:fmt"

main :: proc() {
	ordem := [3]int{1, 2, 3}

	trocado := ordem.zyx
	fmt.println(trocado[0], ordem[0])
}
