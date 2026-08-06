package main

import "core:fmt"

main :: proc() {
	nums := []int{1, 2, 3}
	for &n in nums {
		n *= 2
	}
	fmt.println(nums[0], nums[1], nums[2])
}
