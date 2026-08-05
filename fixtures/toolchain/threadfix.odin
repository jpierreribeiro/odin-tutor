package main
import "core:fmt"
import "core:thread"

main :: proc() {
	a := 1
	b := a + 1
	t := thread.create_and_start(proc() { fmt.println("other thread") })
	c := b + 1
	thread.join(t)
	fmt.println(a, b, c)
}
