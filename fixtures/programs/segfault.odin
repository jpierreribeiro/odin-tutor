package main

import "core:fmt"

// The target dies mid-run. Everything traced before the fault is real and must
// survive: the trace stays valid, and the terminal condition names the signal.
//
// A crash is not an excuse to lose the run. The steps leading to it are exactly
// what the student needs to see (REQ-ERR-001).
main :: proc() {
	a := 1
	fmt.println(a)
	p: ^int
	p^ = 2
}
