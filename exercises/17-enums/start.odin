package main

import "core:fmt"

// `held` must hold one of THREE NAMED VALUES, not a number that stands for one.
//
// The program below prints the right word by looking it up in a table. The
// output is correct and the variable is a 1. Make `held` be the value itself.
//
// Odin writes that as `Key :: enum { Bronze, Silver, Gold }`.
main :: proc() {
	names := [3]string{"Bronze", "Silver", "Gold"}
	held := 1
	fmt.println(names[held])
}
