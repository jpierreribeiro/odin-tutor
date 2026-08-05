package main

import "core:fmt"

add :: proc(a: int, b: int) -> int {
	return a + b
}

main :: proc() {
	total := add(3, 4)
	fmt.println(total)
}
