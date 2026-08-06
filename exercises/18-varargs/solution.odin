package main

import "core:fmt"

total :: proc(nums: ..int) -> int {
	sum := 0
	for n in nums {
		sum += n
	}
	return sum
}

main :: proc() {
	answer := total(1, 2, 3)
	fmt.println(answer)
}
