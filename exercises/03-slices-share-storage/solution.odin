package main

import "core:fmt"

main :: proc() {
	todos := []int{1, 2, 3}
	parte := todos[1:]
	fmt.println(len(todos), len(parte))
}
