	b := a     // a copy: every field, into a new object
	b := &a    // a pointer: the same object, under a second name

Odin copies structs on assignment. There is no hidden sharing to opt out of and
no cost you did not ask for — the copy is the whole struct, and that is all.

In the OBJECTS panel the right answer shows TWO entries, and `a` and `b` point
at different ones. The wrong answer shows a single entry that both names point
at, which is the picture of aliasing you already met in 06.
