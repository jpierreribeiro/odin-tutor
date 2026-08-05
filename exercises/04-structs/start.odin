package main

import "core:fmt"

Student :: struct {
	name: string,
	age:  int,
}

// Build one `student` holding "Ana" and 20.
main :: proc() {
	name := "Ana"
	age := 20
	fmt.println(name, age)
}
