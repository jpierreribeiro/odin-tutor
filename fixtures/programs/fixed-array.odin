package main

import "core:fmt"

// A fixed array carries its length in its type, not beside its data. It must
// not be drawn as a slice: there is no separate storage to share, so a
// shared-storage mark here would teach a distinction that does not exist.
main :: proc() {
	marks: [4]int = {7, 8, 9, 10}
	first := marks[0]
	fmt.println(marks, first)
}
