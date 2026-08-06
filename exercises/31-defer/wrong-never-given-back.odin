package main

import "core:fmt"

Node :: struct {
	value: int,
}

// Prints `7`, exactly like the reference solution, and exits cleanly. Nothing
// in the output says this program walked away from memory it took.
//
// Nor does the object vanishing from the picture: an object leaves the screen
// when it is freed AND when it simply stops being reachable, and those look
// identical (ADR-011). The only honest evidence is the program telling the
// allocator, which the picture reports as GIVEN BACK TO THE ALLOCATOR.
//
// Here that line never appears.
main :: proc() {
	node := new(Node)
	node.value = 7
	fmt.println(node.value)
}
