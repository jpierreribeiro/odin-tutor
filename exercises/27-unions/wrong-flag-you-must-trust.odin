package main

import "core:fmt"

// Prints `42`, exactly like the reference solution.
//
// It also holds a string it is not using, and a boolean that nothing enforces.
// Set `e_numero = false` without touching `numero` and the struct is now
// lying; read `texto` anyway and the compiler will let you.
//
// A union cannot be in that state. The picture shows it holding ONE thing, and
// the name of the thing it holds.
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
