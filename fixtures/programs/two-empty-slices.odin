package main

import "core:fmt"

// THE LIE THIS PREVENTS: two empty slices become one object.
//
// Both have a nil data pointer and length 0, so an identity derived from the
// value alone merges them. The student then sees one variable where two exist,
// and nothing signals the merge (SPEC-TEST-020).
main :: proc() {
	empty1: []int
	empty2: []int
	fmt.println(len(empty1), len(empty2))
}
