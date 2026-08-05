package main

import "core:fmt"

// The reference slice. Measured 2026-08-05: {data, len} read as a pair, len 3,
// elements [7, 8, 9] read through data.
main :: proc() {
	xs := []int{7, 8, 9}
	n := len(xs)
	first := xs[0]
	fmt.println(xs, n, first)
}
