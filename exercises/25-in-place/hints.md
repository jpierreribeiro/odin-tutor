	for &n in nums {
		n *= 2
	}

The `&` is the whole answer. Without it, `n` is a COPY of the element: Odin says
so plainly — iterated values are copies and cannot be written to — and a loop
that computes without storing compiles and prints the right thing.

In the OBJECTS panel, open the slice and read its elements. `{2, 4, 6}` is a
program that changed something. `{1, 2, 3}` under the same printed line is a
program that changed nothing.
