package main

import "core:fmt"

// Print `text` and its LENGTH. The text must read "naïve ✓" and the length
// must be 10.
//
// "naïve ✓" is 7 characters. It is not 7 bytes.
main :: proc() {
	text := "naive"
	fmt.println(text, len(text))
}
