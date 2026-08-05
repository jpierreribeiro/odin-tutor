package main

import "core:fmt"

// A probe target, not a student fixture.
//
// The fixtures under fixtures/programs/ deliberately isolate one thing each.
// This one deliberately combines several, so that one gdb run can answer
// several questions about how the debug information reads. Keeping the two
// kinds apart is the point: a fixture that grew extra variables to serve a
// probe would stop isolating what it was written to isolate.
//
// The map lives here rather than in fixtures/programs/ because TEST-STRATEGY §5
// does not list a map fixture, and the `map-entries` probe still needs a
// target. Adding one to §5 would be inventing a requirement.

Student :: struct {
	name:  string,
	marks: []int,
	age:   int,
}

sum :: proc(xs: []int) -> int {
	total := 0
	for n in xs {
		total += n
	}
	return total
}

main :: proc() {
	marks := []int{7, 8, 9}
	student := Student{name = "Ana", marks = marks, age = 20}
	sub := marks[1:]
	table := make(map[string]int)
	defer delete(table)
	table["a"] = 1
	table["b"] = 2
	total := sum(student.marks)
	node := new(int)
	node^ = 99
	// PROBE-BREAK: every variable above is live and initialised at this line.
	fmt.println(total, sub, node^, student.name, len(table))
	free(node)
}
