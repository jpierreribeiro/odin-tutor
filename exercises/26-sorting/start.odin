package main

import "core:fmt"
import "core:slice"

// This sorts a COPY and prints the copy. `nums` is left as it was.
//
// Sort `nums` itself. `slice.sort` reorders the buffer it is handed — it
// returns nothing, because there is nothing to return.
//
// Then free the copy you no longer need... or rather, do not make one.
main :: proc() {
	nums := []int{9, 1, 4}
	copia := slice.clone(nums)
	defer delete(copia)
	slice.sort(copia)
	fmt.println(copia[0], copia[1], copia[2])
}
