package main

import "core:fmt"

countdown :: proc(n: int) -> int {
	if n == 0 {
		return 0
	}
	return 1 + countdown(n - 1)
}

main :: proc() {
	steps := countdown(4)
	fmt.println(steps)
}
