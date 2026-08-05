package main

import "core:fmt"

Node :: struct {
	value: int,
	next:  ^Node,
}

main :: proc() {
	// two-empty-slices
	empty1: []int
	empty2: []int

	// two-equal-lists
	list1 := []int{1, 2, 3}
	list2 := []int{1, 2, 3}

	// cycle
	cycle_node := new(Node)
	cycle_node.value = 7
	cycle_node.next = cycle_node

	// dynamic array + map
	numbers: [dynamic]int
	append(&numbers, 10)
	append(&numbers, 20)
	table := make(map[string]int)
	table["a"] = 1

	// dangling
	dead := new(int)
	dead^ = 5
	free(dead)

	// corrupt length
	corrupted := list1
	(cast(^int)(uintptr(&corrupted) + size_of(rawptr)))^ = 4_000_000_000

	// free-then-allocate
	first := new(int)
	first^ = 1
	free(first)
	second := new(int)
	second^ = 2

	// utf8
	text := "naïve ✓"

	fmt.println(
		len(empty1),
		len(empty2),
		list1,
		list2,
		cycle_node.value,
		numbers[:],
		len(table),
		dead,
		len(text),
		second^,
	)
	_ = corrupted
}
