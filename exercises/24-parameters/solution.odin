package main

import "core:fmt"

dobrar :: proc(n: ^int) {
	n^ *= 2
}

main :: proc() {
	total := 3
	dobrar(&total)
	fmt.println(total)
}
