package main

import "core:fmt"

Node :: struct {
	value: int,
	next:  ^Node,
}

// Four nodes, one chain. Expansion reaches all four and stops at nil, well
// inside expansions_per_step = 32 (SAFETY.md §4). The reference shape for the
// object graph.
main :: proc() {
	fourth := new(Node)
	fourth.value = 4
	third := new(Node)
	third.value = 3
	third.next = fourth
	second := new(Node)
	second.value = 2
	second.next = third
	first := new(Node)
	first.value = 1
	first.next = second
	fmt.println(first.value, first.next.next.value)
	free(fourth)
	free(third)
	free(second)
	free(first)
}
