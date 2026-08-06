package main

import "core:fmt"

// `User_Id` is an ALIAS below, which means it IS `int`. Passing an age where an
// id belongs compiles, and the mistake reaches production.
//
// Make it a type of its own with `distinct`, and the compiler starts refusing
// what it cannot check today. The bytes do not change, the printed output does
// not change, and `id` needs `User_Id(7)` to be built.
User_Id :: int

main :: proc() {
	id := User_Id(7)
	idade := 7
	fmt.println(id, idade)
}
