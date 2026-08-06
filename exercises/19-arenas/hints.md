`new` takes an allocator as its second argument:

	primeiro := new(int, mem.arena_allocator(&arena))

An arena is a block of memory and a mark. Allocating moves the mark forward;
nothing is given back one piece at a time.

In the OBJECTS panel, open `arena` and watch `offset`. Each `int` is eight
bytes, so after two of them the mark reads 16. Take them from the general
allocator instead and it reads 0 — the arena is there, correct, and unused.
