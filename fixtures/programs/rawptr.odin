package main

import "core:fmt"

// THE LIE THIS PREVENTS: an invented target for an unshaped pointer.
//
// A rawptr has no target type, so "it looks like a struct" is a guess, and a
// guess drawn as a picture is indistinguishable from knowledge
// (SPEC-MEM-031, AGENT-GUIDE §6). Expected: the pointer value is recorded and
// zero reads happen through it.
main :: proc() {
	value := 42
	unshaped: rawptr = &value
	fmt.println(value, unshaped != nil)
}
