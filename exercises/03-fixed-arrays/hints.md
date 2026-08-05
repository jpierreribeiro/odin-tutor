`marks: [4]int = {...}` declares a fixed array. `marks := []int{...}` declares a
slice.

Look at the type in the OBJECTS panel. A fixed array shows its length inside the
type; a slice shows `[]int` and carries its length as a separate number.

That is why a slice can share storage with another slice and a fixed array
cannot: a slice POINTS AT storage, and a fixed array IS storage.

One wrinkle to know about, because you will see it: the debugger reports the
type in C's order, so Odin's `[4]int` appears as `int [4]`. The tool shows what
the debug information says rather than translating it, because a translation
that is wrong somewhere is worse than a spelling you have to learn once.
