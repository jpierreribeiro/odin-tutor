package main

import "core:fmt"

Node :: struct {
	value: int,
}

// A plausible wrong solution: the allocation is right and the assignment is
// missing. Odin zeroes what it allocates, so this prints 0 rather than
// crashing — the object exists and holds the wrong thing.
main :: proc() {
	node := new(Node)
	fmt.println(node.value)
	free(node)
}
