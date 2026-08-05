A `^Counter` parameter takes the address of a counter. A `Counter` parameter
takes a copy of one.

In the FRAMES panel, look at what `p` shows. `p -> [2]` means it refers to
object 2. The OBJECTS panel shows object 2 once, and both `counter` and anything
else pointing at it name the same number.

A copy would appear as a second object with its own number.
