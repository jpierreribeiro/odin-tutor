package main

import "core:fmt"

Student :: struct {
	name: string,
	age:  int,
}

main :: proc() {
	student := Student{name = "Ana", age = 20}
	fmt.println(student.name, student.age)
}
