package main

import "core:fmt"

// THE WORKED EXAMPLE of SPEC-EX-052.
//
// This prints "3 2", exactly like the reference solution. Every test that
// checks output alone accepts it. It is still wrong: `parte` is a second array
// holding equal values, not a window onto the first, so writing through one is
// not visible through the other.
//
// The memory assertions reject it. That is the whole reason this tool draws
// pictures instead of comparing printed text.
main :: proc() {
	todos := []int{1, 2, 3}
	parte := []int{2, 3}
	fmt.println(len(todos), len(parte))
}
