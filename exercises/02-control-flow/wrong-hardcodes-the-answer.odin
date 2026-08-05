package main

import "core:fmt"

// A plausible wrong solution: the right number, written down. It prints 10 and
// `total` really does hold 10, so both the output and the value are correct.
//
// There is no loop, so there is no `i` to watch and no step to go back to.
main :: proc() {
	total := 10
	fmt.println(total)
}
