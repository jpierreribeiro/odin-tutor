package main

import "core:fmt"

// THE LIE THIS PREVENTS: a sub-slice drawn with its parent's length, or given a
// storage of its own so the sharing disappears from the picture.
//
// Measured 2026-08-05: sub's data pointer sits 8 bytes past marks's, so the
// overlap is detectable from the observation alone — no guessing required.
// Expected: two view identities, one storage, lengths 3 and 2, sharing
// recorded (SPEC-TEST-020).
main :: proc() {
	marks := []int{7, 8, 9}
	sub := marks[1:]
	fmt.println(marks, sub, len(marks), len(sub))
}
