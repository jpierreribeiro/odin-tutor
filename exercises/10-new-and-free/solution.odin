package main

import "core:fmt"

Node :: struct {
	value: int,
}

main :: proc() {
	node := new(Node)
	node.value = 7
	fmt.println(node.value)
	free(node)
}
