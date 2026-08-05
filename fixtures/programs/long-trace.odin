package main

import "core:fmt"

// Three lines in the body, 1000 iterations: past steps = 2500 (SAFETY.md §4).
//
// SPEC-PERF-020: assembly cost stays linear in steps, and the budget check is
// O(new data), never O(total). SPEC-SAFE-031 records a prior system whose size
// check re-serialised the whole accumulated document at every step. Measuring
// cost more than the time budget, so the step limit could never be reached and
// a long trace failed by timeout inside the measuring code.
main :: proc() {
	total := 0
	for i in 0 ..< 1000 {
		doubled := i * 2
		total += doubled
		total -= i
	}
	fmt.println(total)
}
