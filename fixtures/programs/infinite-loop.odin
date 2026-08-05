package main

// The program never ends. The run is bounded by steps = 2500 and
// wall_ms = 60 000 (SAFETY.md §4).
//
// SPEC-SAFE-030: reaching a budget produces a valid trace with a truncation
// record. Not a hang, and not a lost run — the student still sees the 2500
// steps that did happen, marked as incomplete.
//
// The comparison is here so the counter is read as well as written. It never
// becomes true.
main :: proc() {
	n := 0
	for {
		n += 1
		if n < 0 {
			break
		}
	}
}
