package main

import "core:fmt"

Node :: struct {
	value: int,
}

// This program takes memory and never gives it back.
//
// Give it back with `defer free(node)`, on the line right after the
// allocation. `defer` runs when the scope ends, so the giving-back sits beside
// the taking — and it still happens if the procedure later returns from
// somewhere else, which a `free` at the bottom does not.
//
// The printed output does not change. What changes is whether anything died.
main :: proc() {
	node := new(Node)
	node.value = 7
	fmt.println(node.value)
}
