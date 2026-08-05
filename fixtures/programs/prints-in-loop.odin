package main

import "core:fmt"

// The student's stdout and the trace are two streams produced by one run. The
// tool must not lose either, and must not reorder the output relative to the
// steps that produced it.
main :: proc() {
	for i in 0 ..< 5 {
		fmt.println("line", i)
	}
}
