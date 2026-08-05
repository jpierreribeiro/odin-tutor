package main

import "core:fmt"

// A string is read through its {data, len} pair, not as a null-terminated run
// of bytes. Measured 2026-08-05: "Ana" read with len = 3.
main :: proc() {
	name := "Ana"
	empty := ""
	length := len(name)
	fmt.println(name, length, len(empty))
}
