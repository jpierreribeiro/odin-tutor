package main

import "core:fmt"
import "core:thread"

// THE LIE THIS PREVENTS: memory written by another thread drawn as if a shown
// line produced it.
//
// ADR-012: the model assumes one thread. Adding threads is not an increment, it
// is a new model. So the trace must END before the second thread runs, carrying
// TARGET_BECAME_MULTITHREADED, and still parse (REQ-EXEC-007).
//
// Measured 2026-08-05, and it refuted the obvious implementation: counting
// threads at each stop detects NOTHING here. This thread was created and exited
// between two stops, so a per-stop count never fires. Only
// gdb.events.new_thread catches it, ignoring thread number 1.
//
// That is worse than having no safeguard, because its presence implies
// protection that is not there.
main :: proc() {
	a := 1
	b := a + 1
	worker := thread.create_and_start(proc() {
		fmt.println("other thread")
	})
	c := b + 1
	thread.join(worker)
	thread.destroy(worker)
	fmt.println(a, b, c)
}
