package main

import "core:fmt"

// `guardado` must hold EITHER an int OR a string, and know which.
//
// The struct below holds both at all times and a boolean you have to remember
// to check. Nothing stops someone reading `texto` while `e_numero` is true, and
// the picture shows two fields where there is only ever one value.
//
// Odin writes the honest version as `union { int, string }`. Then a type
// assertion — `guardado.(int)` — asks for the variant and tells you whether it
// was the right one.
Guardado :: struct {
	numero:    int,
	texto:     string,
	e_numero:  bool,
}

main :: proc() {
	guardado := Guardado{numero = 42, e_numero = true}
	if guardado.e_numero {
		fmt.println(guardado.numero)
	}
}
