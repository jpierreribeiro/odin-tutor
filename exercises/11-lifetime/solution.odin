package main

import "core:fmt"

Node :: struct {
	value: int,
}

main :: proc() {
	node := new(Node)
	node.value = 3
	value := node.value
	free(node)
	node = nil
	fmt.println(value, node == nil)
}
