package main

import "core:fmt"

divide :: proc(a: int, b: int) -> (int, bool) {
	if b == 0 {
		return 0, false
	}
	return a / b, true
}

main :: proc() {
	result, ok := divide(8, 0)
	if ok {
		fmt.println(result)
	} else {
		fmt.println("cannot divide by zero")
	}
}
