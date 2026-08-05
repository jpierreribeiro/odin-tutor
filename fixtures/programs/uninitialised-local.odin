package main

import "core:fmt"

// THIS FIXTURE RECORDS A LIMIT. It does not assert a safeguard. R-22.
//
// The intent was: stack garbage must never be shown as a value. Measured
// 2026-08-05, that is not achievable here by reading.
//
// `x: int = ---` leaves the storage untouched on purpose, and it generates no
// code — so its declaring line never appears in the line table and is never a
// step. From the first step onward the declaration has been passed, the
// variable is in scope, and the tool reads what the previous call left there.
// This run showed 140729712422976.
//
// DWARF says where a variable lives and where it was declared. It does not say
// whether it has ever been assigned. There is nothing to read.
//
// WHAT DOES WORK is the case the state was built for: a local or an argument
// read BEFORE its declaration line. That is `prologue`, and it is detected.
// `y` below is `not-yet-active` at the step before its own declaration.
//
// So this fixture asserts the current behaviour, so that a change is loud, and
// the documentation must not claim the tool finds uninitialised reads.
main :: proc() {
	x: int = ---
	y := 1
	x = y + 1
	fmt.println(x, y)
}
