package main
import "core:fmt"
import "core:mem"

No :: struct { valor: int, prox: ^No }

main :: proc() {
	// two-empty-slices
	vazia1: []int
	vazia2: []int

	// two-equal-lists
	l1 := []int{1, 2, 3}
	l2 := []int{1, 2, 3}

	// cycle
	c := new(No); c.valor = 7; c.prox = c

	// dynamic array + map
	din: [dynamic]int
	append(&din, 10); append(&din, 20)
	m := make(map[string]int); m["a"] = 1

	// dangling
	morto := new(int); morto^ = 5
	free(morto)

	// corrupt length
	corrompida := l1
	(cast(^int)(uintptr(&corrompida) + size_of(rawptr)))^ = 4_000_000_000

	// free-then-allocate
	p1 := new(int); p1^ = 1
	free(p1)
	p2 := new(int); p2^ = 2

	// utf8
	txt := "coração ✓"

	fmt.println(len(vazia1), len(vazia2), l1, l2, c.valor, din[:], len(m), morto, len(txt), p2^)
	_ = corrompida
}
