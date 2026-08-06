package main

import "core:fmt"
import "core:slice"

main :: proc() {
	nums := []int{9, 1, 4}
	slice.sort(nums)
	fmt.println(nums[0], nums[1], nums[2])
}
