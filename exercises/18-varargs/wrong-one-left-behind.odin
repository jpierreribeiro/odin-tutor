package main

import "core:fmt"

// Prints `6`, exactly like the reference solution.
//
// The procedure is variadic and the loop is right. What is wrong is at the CALL
// SITE: only two of the three numbers were passed, and the third was added
// afterwards by hand. The answer is correct by accident.
//
// You cannot see that in the output. You can see it in the picture: `nums` is a
// slice of length 2.
total :: proc(nums: ..int) -> int {
	sum := 0
	for n in nums {
		sum += n
	}
	return sum
}

main :: proc() {
	answer := total(1, 2) + 3
	fmt.println(answer)
}
