package main

import "core:fmt"

// THE LIE THIS PREVENTS: equal contents become one object.
//
// Both lists hold the same three values in different storage. Identity is not
// equality (SPEC-MEM-001). The second is filled at run time on purpose: two
// identical literals may be merged into one constant by the compiler, and then
// the fixture would be asserting something the program never did.
main :: proc() {
	literal := []int{1, 2, 3}
	built := make([]int, 3)
	defer delete(built)
	built[0] = 1
	built[1] = 2
	built[2] = 3
	fmt.println(literal, built)
}
