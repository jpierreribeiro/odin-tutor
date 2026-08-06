	slice.sort(nums)

It returns nothing. That is the point: it reorders the buffer `nums` points at,
so everyone holding that buffer — including any sub-slice of it — sees the new
order.

`slice.clone` makes a second buffer. Sorting that one is a real thing to want
sometimes, and it is not this: the original keeps its order, and the copy is
memory you now have to free.

In the OBJECTS panel, read the elements of `nums` after the sort. `1 4 9` is a
program that sorted something. `9 1 4` under a printed `1 4 9` is a program that
sorted something else.
