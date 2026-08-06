package main

import "core:fmt"
import "core:mem"

main :: proc() {
	buffer: [256]byte
	arena: mem.Arena
	mem.arena_init(&arena, buffer[:])

	primeiro := new(int, mem.arena_allocator(&arena))
	segundo := new(int, mem.arena_allocator(&arena))
	primeiro^ = 3
	segundo^ = 4
	fmt.println(primeiro^, segundo^)
}
