package main

import "core:fmt"

Guardado :: union {
	int,
	string,
}

main :: proc() {
	guardado: Guardado = 42
	numero, e_numero := guardado.(int)
	if e_numero {
		fmt.println(numero)
	}
}
