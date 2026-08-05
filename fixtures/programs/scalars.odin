package main

import "core:fmt"

// The walking-skeleton target. One assignment per line, so the step count is
// checkable against the source rather than against the tool's own output
// (ROADMAP Phase 1, acceptance 1).
main :: proc() {
	a := 1
	b := 2
	c := a + b
	f := 1.5
	ok := c > 2
	fmt.println(a, b, c, f, ok)
}
