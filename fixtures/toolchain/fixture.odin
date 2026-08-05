package main
import "core:fmt"

Aluno :: struct {
	nome:  string,
	notas: []int,
	idade: int,
}

soma :: proc(xs: []int) -> int {
	total := 0
	for n in xs {
		total += n
	}
	return total
}

fib :: proc(n: int) -> int {
	if n < 2 { return n }
	return fib(n-1) + fib(n-2)
}

main :: proc() {
	notas := []int{7, 8, 9}
	a := Aluno{nome = "Ana", notas = notas, idade = 20}
	sub := notas[1:]
	t := soma(a.notas)
	f := fib(6)
	no := new(int)
	no^ = 99
	fmt.println(t, f, sub, no^, a.nome)
	free(no)
}
