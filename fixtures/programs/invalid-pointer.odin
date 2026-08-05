package main

import "core:fmt"

Node :: struct {
	value: int,
	next:  ^Node,
}

// THE LIE THIS PREVENTS: a fabricated object behind an unmapped address.
//
// Measured 2026-08-05: reading 0xdeadbeef raises a catchable gdb.MemoryError.
// The program never dereferences it — the TRACER is the one that tries, and it
// must record `unreadable` and complete the run (SPEC-TEST-020).
//
// THE POINTER MUST BE TO A STRUCT. SPEC-MEM-031 forbids following a pointer to
// a scalar, so a `^int` at a bad address is never read and this fixture would
// exercise nothing at all — it would pass while testing the absence of a
// feature rather than the presence of a safeguard.
main :: proc() {
	unmapped := cast(^Node)(uintptr(0xdeadbeef))
	valid := new(Node)
	valid.value = 1
	fmt.println(unmapped != nil, valid.value)
	free(valid)
}
