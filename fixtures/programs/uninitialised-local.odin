package main

import "core:fmt"

// THE LIE THIS PREVENTS: stack garbage shown as a value.
//
// Odin zeroes by default, so `= ---` is used deliberately to leave the storage
// untouched. That is the case the tool must not read as a value.
//
// Expected: `not-yet-active` at the declaring line, `valid` after the
// assignment. Merging `not-yet-active` with `unknown` because both render blank
// loses the difference between "not born yet" and "I could not read it"
// (AGENT-GUIDE §6).
main :: proc() {
	x: int = ---
	y := 1
	x = y + 1
	fmt.println(x, y)
}
