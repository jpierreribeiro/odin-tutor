package main

import "core:fmt"

Node :: struct {
	value: int,
}

// Allocate, use it, give it back — and then record that `node` no longer
// points at anything.
//
// The tool CANNOT tell you that a pointer is dangling. A freed region stays
// mapped and reads back as a plausible number. `nil` is the only way the fact
// gets written down.
main :: proc() {
	node := new(Node)
	node.value = 3
	fmt.println(node.value, node == nil)
	free(node)
}
