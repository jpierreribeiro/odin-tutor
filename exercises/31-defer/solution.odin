package main

import "core:fmt"

Node :: struct {
	value: int,
}

main :: proc() {
	node := new(Node)
	defer free(node)

	node.value = 7
	fmt.println(node.value)
}
