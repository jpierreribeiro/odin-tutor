package main

import "core:fmt"

main :: proc() {
	total := 0
	for i in 1 ..= 4 {
		total += i
	}
	fmt.println(total)
}
