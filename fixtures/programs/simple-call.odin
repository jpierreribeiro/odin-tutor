package main

import "core:fmt"

double :: proc(n: int) -> int {
	return n * 2
}

// The other half of the fibonacci pair. Phase 3 acceptance 3: the return value
// IS shown here.
//
// Without this fixture, "no shown return value contradicts its frame" passes by
// showing nothing at all. A prior system's return-never-lies check became
// vacuously true exactly that way, and nothing noticed (SPEC-TEST-022).
main :: proc() {
	x := 21
	y := double(x)
	fmt.println(y)
}
