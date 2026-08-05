package main

import "core:fmt"

// A plausible wrong solution: a trailing space nobody sees.
//
// The printed line looks right at a glance and the length is 4. A string's
// length is stored beside its data, so it counts every byte that is there —
// including the one you cannot see between the text and the number.
main :: proc() {
	name := "Ana "
	fmt.println(name, len(name))
}
