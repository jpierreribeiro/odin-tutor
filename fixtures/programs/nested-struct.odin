package main

import "core:fmt"

Address :: struct {
	street: string,
	number: int,
}

Student :: struct {
	name:    string,
	address: Address,
}

// A struct inside a struct is one storage, not two. The inner fields are
// reached by field path. Nothing is followed, because there is no pointer here
// — drawing an arrow would invent a relationship (ADR-007).
main :: proc() {
	student := Student{name = "Ana", address = Address{street = "Central", number = 12}}
	number := student.address.number
	fmt.println(student.name, student.address.street, number)
}
