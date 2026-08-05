package main

import "core:fmt"

// THE LIE THIS PREVENTS: thirty plausible elements read from a corrupt length.
//
// The length field is overwritten with a value no allocation could justify.
// SPEC-SAFE-010: the length is validated BEFORE any read, and the value becomes
// `unknown`.
//
// Reading min(length, budget) elements is the tempting change AGENT-GUIDE §6
// forbids. It produces thirty believable integers out of whatever bytes follow,
// and the student has no signal that any of it is garbage.
//
// Expected: `unknown` for the value, and no read exceeding the bound — asserted
// by instrumenting the adapter's read sizes, not by the absence of a crash.
main :: proc() {
	xs := []int{1, 2, 3}
	corrupted := xs
	length_field := cast(^int)(uintptr(&corrupted) + size_of(rawptr))
	length_field^ = 4_000_000_000
	fmt.println(len(xs))
}
