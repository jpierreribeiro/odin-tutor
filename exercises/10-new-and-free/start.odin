package main

import "core:fmt"

Node :: struct {
	value: int,
}

// Allocate a Node on the heap, put 7 in it, print it, and give it back.
main :: proc() {
	value := 7
	fmt.println(value)
}
