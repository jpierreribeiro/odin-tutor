package main

import "core:fmt"

// KNOWN INCORRECT IN VERSION 1. SPEC-TEST-021.
//
// `second` is handed `first`'s address. Version 1 has no allocation events, so
// it cannot tell reuse from continuity, and the new object inherits the freed
// object's identity (SPEC-MEM-042).
//
// The test asserts that WRONG behaviour on purpose. A known gap with a test is
// engineering; a known gap without one is a rumour. When Phase 6 closes it, the
// test is replaced rather than quietly deleted, and REQ-MEM-003 stops being
// "partly met".
//
// WHY THE WARM-UP LOOP IS HERE. Measured 2026-08-05 on
// dev-2026-07-nightly:819fdc7, because the obvious shape does not reuse:
//
//   new, free, new                     20 cycles, 20 different addresses
//   new, new, free the first, new      no reuse from a cold allocator
//   8 live, free the middle one, new   no reuse
//
// The allocator hands out fresh addresses until enough blocks have come back to
// it. The threshold measured between 4 and 8 freed 8-byte blocks; 16 is used
// for margin. With the loop, reuse happens on every run.
//
// Without it this fixture is INERT. The two objects get different addresses, so
// they get different identities anyway, and the test meant to pin the
// incorrectness passes while testing nothing — the same vacuous-check failure
// SPEC-TEST-022 was written against.
main :: proc() {
	warmup := make([]^int, 16)
	for i in 0 ..< 16 {
		warmup[i] = new(int)
	}
	for i in 0 ..< 16 {
		free(warmup[i])
	}
	delete(warmup)

	first := new(int)
	first^ = 1
	neighbour := new(int)
	neighbour^ = 9
	free(first)
	second := new(int)
	second^ = 2
	fmt.println(second^, neighbour^, uintptr(first) == uintptr(second))
	free(neighbour)
	free(second)
}
