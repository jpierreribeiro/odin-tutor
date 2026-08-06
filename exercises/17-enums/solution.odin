package main

import "core:fmt"

Key :: enum {
	Bronze,
	Silver,
	Gold,
}

main :: proc() {
	held := Key.Silver
	fmt.println(held)
}
