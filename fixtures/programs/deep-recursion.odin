package main

import "core:fmt"

count_down :: proc(n: int) -> int {
	if n == 0 {
		return 0
	}
	return 1 + count_down(n - 1)
}

// Frame identity at depth. The 2026-08-05 probe walked depth 7; this reaches
// 100, past anything a teaching example needs, so the frame panel and the
// (pc, sp) key are exercised where a per-frame cost would show up.
main :: proc() {
	depth := count_down(100)
	fmt.println(depth)
}
