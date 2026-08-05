package main

import "core:fmt"

// THE LIE THIS PREVENTS: a fabricated object behind an unmapped address.
//
// Measured 2026-08-05: reading 0xdeadbeef raises a catchable gdb.MemoryError.
// The program never dereferences it — the TRACER is the one that tries, and it
// must record `unreadable` and complete the run (SPEC-TEST-020).
main :: proc() {
	unmapped := cast(^int)(uintptr(0xdeadbeef))
	valid := new(int)
	valid^ = 1
	fmt.println(unmapped != nil, valid^)
	free(valid)
}
