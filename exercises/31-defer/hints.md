	node := new(Node)
	defer free(node)

`defer` does not run the statement now. It runs it when the scope ends — here,
when `main` returns — whichever line returns.

Step to the end of the run and look under the OBJECTS panel for

	GIVEN BACK TO THE ALLOCATOR AT THIS STEP: [2]

That line is the only proof. An object disappearing from the picture is NOT
proof: it also disappears when nothing points at it any more, and a leak looks
exactly like a tidy program from the outside. This tool refuses to guess between
them, so it reports what the program actually said.
