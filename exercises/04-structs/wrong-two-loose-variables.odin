package main

import "core:fmt"

Student :: struct {
	name: string,
	age:  int,
}

// A plausible wrong solution: two variables that happen to be printed together.
// The output is identical. There is no `student`, so nothing groups them and
// nothing stops the two drifting apart.
main :: proc() {
	name := "Ana"
	age := 20
	fmt.println(name, age)
}
