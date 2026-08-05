package main

import "core:fmt"

Node :: struct {
	value: int,
	next:  ^Node,
}

// SPEC-TEST-061: at least one golden shows all four value states in ONE screen,
// so that a change merging any two of them fails a test.
//
// This fixture exists for that golden and for nothing else. Each line below
// produces exactly one state at the marked step:
//
//   valid           `shown`, an ordinary integer
//   unknown         `corrupted`, whose length no allocation could justify
//   unreadable      the target of `unmapped`, at an address that is not mapped
//   not-yet-active  `later`, declared below the line being shown
//
// The four never share a visible form. "Both render blank" would tell a student
// that "not created yet" and "I could not read it" are the same thing, and a
// blank slot is itself a claim that there is nothing there (SPEC-TUI-010).
main :: proc() {
	shown := 7
	corrupted := []int{1, 2, 3}
	length_field := cast(^int)(uintptr(&corrupted) + size_of(rawptr))
	length_field^ = 4_000_000_000
	unmapped := cast(^Node)(uintptr(0xdeadbeef))
	fmt.println(shown, unmapped != nil)
	later := 1
	fmt.println(later)
}
