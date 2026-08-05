package main

import "core:fmt"

Node :: struct {
	value: int,
	next:  ^Node,
}

// THE LIE THIS PREVENTS: infinite expansion, or a cycle drawn as an endless
// chain of distinct objects.
//
// The node points at itself. Expansion keeps a visited set and terminates
// (REQ-MEM-011, SPEC-PERF-024), and the field shows the object's OWN
// identifier — which is what tells the student it is a cycle rather than a
// picture that ran out of room (SPEC-TEST-020).
main :: proc() {
	node := new(Node)
	node.value = 7
	node.next = node
	fmt.println(node.value, node.next.value)
	free(node)
}
