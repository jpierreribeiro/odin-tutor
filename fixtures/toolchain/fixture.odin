package main

import "core:fmt"

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

fib :: proc(n: int) -> int {
	if n < 2 {
		return n
	}
	return fib(n - 1) + fib(n - 2)
}

main :: proc() {
	marks := []int{7, 8, 9}
	student := Student{name = "Ana", marks = marks, age = 20}
	sub := marks[1:]
	total := sum(student.marks)
	fib_result := fib(6)
	node := new(int)
	node^ = 99
	fmt.println(total, fib_result, sub, node^, student.name)
	free(node)
}
