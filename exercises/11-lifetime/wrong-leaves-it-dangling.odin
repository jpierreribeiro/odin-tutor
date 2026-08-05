package main

import "core:fmt"

Node :: struct {
	value: int,
}

// A plausible wrong solution: free it and leave the pointer alone.
//
// It prints "3 false" and nothing crashes. `node` still holds an address, the
// memory there still reads, and every later line that uses it is a bug the
// program will not report. R-21: this tool cannot detect that either — which is
// exactly why nil is your job and not its.
main :: proc() {
	node := new(Node)
	node.value = 3
	value := node.value
	free(node)
	fmt.println(value, node == nil)
}
