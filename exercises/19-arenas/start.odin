package main

import "core:fmt"
import "core:mem"

// Both allocations below come from the general allocator, and each one has to
// be given back on its own.
//
// Take them from the ARENA instead, by passing `mem.arena_allocator(&arena)` as
// the allocator. Nothing about the output changes. What changes is that the
// arena's `offset` moves by exactly what you took, and everything in it dies at
// once when the buffer goes away — so there is nothing left to free by hand.
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
