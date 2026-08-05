package main

import "core:fmt"

Node :: struct {
	value: int,
}

// A plausible wrong solution: a local where the exercise asked for an
// allocation. It prints 7 and it compiles.
//
// Until SPEC-VAL-024 this exercise ACCEPTED it. A local struct and a pointer to
// one both resolve to an object, so every predicate available read the same on
// both, and the exercise could not say what it meant. `is_reference` is that
// predicate.
main :: proc() {
	node := Node{value = 7}
	fmt.println(node.value)
}
