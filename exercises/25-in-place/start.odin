package main

import "core:fmt"

// The doubling below happens on the way to being printed, and `nums` never
// changes.
//
// Double the slice ITSELF. Odin iterates by reference with `for &n in nums`,
// and then `n` is the element, not a copy of it.
main :: proc() {
	nums := []int{1, 2, 3}
	fmt.println(nums[0] * 2, nums[1] * 2, nums[2] * 2)
}
