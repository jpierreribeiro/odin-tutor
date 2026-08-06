package main

import "core:fmt"

main :: proc() {
	vistos := make(map[string]bool)
	defer delete(vistos)

	vistos["ana"] = true
	vistos["bo"] = true
	vistos["ana"] = true

	fmt.println(len(vistos))
}
