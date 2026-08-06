A `^Counter` parameter takes the address of a counter. A `Counter` parameter
takes a copy of one.

In the FRAMES panel, look at what `p` shows. `p -> [2]` means it refers to
object 2. The OBJECTS panel shows object 2 once, and both `counter` and anything
else pointing at it name the same number.

A copy would appear as a second object with its own number.

In the FRAMES panel, look at `c` inside `bump` while the call is running. A
pointer parameter shows an arrow to the same object `counter` names. A value
parameter shows an object of its own — a copy, which the procedure then writes
into and throws away.
