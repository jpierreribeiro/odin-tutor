package main

import "core:fmt"

// A plausible wrong solution: ten ASCII letters. `len` says 10 and the number
// is right, and nothing about bytes against characters has been learned.
main :: proc() {
	text := "abcdefghij"
	fmt.println(text, len(text))
}
