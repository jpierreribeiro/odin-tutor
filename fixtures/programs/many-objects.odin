package main

import "core:fmt"

Node :: struct {
	value: int,
	next:  ^Node,
}

// Past objects_per_step = 200 (SAFETY.md §4). 250 nodes hang off one root and
// are all reachable at one step.
//
// This budget is enforced by the CORE, not the adapter: it is a property of the
// assembled step, not of a read. SPEC-SAFE-030 — the step carries a truncation
// record and the trace stays valid.
main :: proc() {
	root: ^Node
	for i in 0 ..< 250 {
		node := new(Node)
		node.value = i
		node.next = root
		root = node
	}
	fmt.println(root.value)
	for root != nil {
		next := root.next
		free(root)
		root = next
	}
}
