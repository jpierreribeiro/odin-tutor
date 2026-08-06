package main

import "core:fmt"

main :: proc() {
	a := [3]int{1, 2, 3}
	b := [3]int{10, 20, 30}

	soma := a + b
	fmt.println(soma[0], soma[1])
}
