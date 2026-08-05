package main

import "core:fmt"

Student :: struct {
	name: string,
	age:  int,
}

// A typed pointer is followed, and its target is drawn as an object with its
// own identity. Writing through the pointer changes what the variable shows,
// which is the whole point of the picture: the pointer holds a reference, not a
// copy.
main :: proc() {
	student := Student{name = "Ana", age = 20}
	p := &student
	p.age = 21
	fmt.println(student.age, p.name)
}
