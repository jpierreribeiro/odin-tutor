package main

import "core:fmt"

fib :: proc(n: int) -> int {
	if n < 2 {
		return n
	}
	return fib(n - 1) + fib(n - 2)
}

// THE LIE THIS PREVENTS: a return value attributed to the wrong invocation.
//
// Measured 2026-08-05: fib(6) produced 25 invocations, 25 return values, and
// zero wrong values. Frame identity under recursion was the least validated
// part of the design; it now has evidence.
//
// The test is a PROPERTY, not a list of expected values (SPEC-TEST-022):
// every shown return value equals the correct result for its frame's argument.
// A trace showing no return values passes it — withholding is allowed, lying is
// not — which is why simple-call exists as the other half of the pair.
//
// The trap that cost the probe run time: a FinishBreakpoint whose stop()
// returns True on a recursive procedure that also carries an ordinary
// breakpoint never fires as expected, because the deeper call interleaves
// first. Return False.
main :: proc() {
	f := fib(6)
	fmt.println(f)
}
