package main

import "core:fmt"

// A plausible wrong solution: return 0 and call it success. The program prints
// 0, which is a number the student will believe.
//
// This is the shape of the mistake the whole project is about. A wrong answer
// that looks like an answer is worse than no answer, and the second return
// value is how Odin lets you say "there is none".
divide :: proc(a: int, b: int) -> (int, bool) {
	if b == 0 {
		return 0, true
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
