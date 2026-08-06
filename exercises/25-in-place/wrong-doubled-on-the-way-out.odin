package main

import "core:fmt"

// Prints `2 4 6`, exactly like the reference solution.
//
// Nothing was doubled. Each number was multiplied on its way to the screen and
// the slice still holds 1, 2, 3 — so anything that reads `nums` after this line
// gets the old values, and the program looks correct until it is used.
//
// The output cannot see the difference. The picture can: open `nums` in the
// OBJECTS panel.
main :: proc() {
	nums := []int{1, 2, 3}
	fmt.println(nums[0] * 2, nums[1] * 2, nums[2] * 2)
}
