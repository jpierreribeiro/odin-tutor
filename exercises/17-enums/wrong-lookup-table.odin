package main

import "core:fmt"

// Prints `Silver`, exactly like the reference solution. The output cannot tell
// you which of the two you wrote.
//
// But `held` is a 1. Nothing in it says what it means, nothing stops it being
// set to 7, and reading the picture tells you only which slot of a table
// somebody happened to index.
main :: proc() {
	names := [3]string{"Bronze", "Silver", "Gold"}
	held := 1
	fmt.println(names[held])
}
