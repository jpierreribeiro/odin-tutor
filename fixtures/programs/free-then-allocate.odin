package main

import "core:fmt"

Node :: struct {
	value: int,
}

// CLOSED BY PHASE 6a, 2026-08-05. It was KNOWN INCORRECT in version 1.
//
// `second` is handed `first`'s address. Version 1 had no allocation events, so
// it could not tell reuse from continuity, and the new object inherited the
// freed object's identity (SPEC-MEM-042).
//
// Phase 6a closed it. The adapter now breaks on the free path and records that
// the storage died, which is POSITIVE evidence — the one thing the absence rule
// could never supply. The two objects get two identities.
//
// The pointers are ^Node rather than ^int on purpose: SPEC-MEM-031 forbids
// following a pointer to a scalar, so with ^int there is no object, no identity,
// and nothing for this fixture to be about.
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
	warmup := make([]^Node, 16)
	for i in 0 ..< 16 {
		warmup[i] = new(Node)
	}
	for i in 0 ..< 16 {
		free(warmup[i])
	}
	delete(warmup)

	first := new(Node)
	first.value = 1
	neighbour := new(Node)
	neighbour.value = 9
	free(first)
	second := new(Node)
	second.value = 2
	fmt.println(second.value, neighbour.value, uintptr(first) == uintptr(second))
	free(neighbour)
	free(second)
}
