package main

import "core:fmt"

// Prints `7 7`, exactly like the reference solution. Both variables hold the
// same eight bytes, and every value assertion passes on both.
//
// `User_Id :: int` is an alias: the two names ARE one type. Nothing stops an
// age being passed where an id belongs, and nothing on this screen would have
// warned you — until the picture started naming the type.
//
// In the FRAMES panel the right answer reads `id: main::User_Id = 7`. This one
// reads `id = 7`, exactly like `idade`.
User_Id :: int

main :: proc() {
	id := User_Id(7)
	idade := 7
	fmt.println(id, idade)
}
