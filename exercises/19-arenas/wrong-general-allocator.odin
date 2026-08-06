package main

import "core:fmt"
import "core:mem"

// Prints `3 4`, exactly like the reference solution, and the arena is right
// there, initialised and correct.
//
// It is never used. Both allocations came from the general allocator, so the
// arena's `offset` is still 0 — the mark never moved, because nothing was ever
// taken from it. That number is the only place the difference appears.
main :: proc() {
	buffer: [256]byte
	arena: mem.Arena
	mem.arena_init(&arena, buffer[:])

	primeiro := new(int)
	segundo := new(int)
	primeiro^ = 3
	segundo^ = 4
	fmt.println(primeiro^, segundo^)
	free(primeiro)
	free(segundo)
}
