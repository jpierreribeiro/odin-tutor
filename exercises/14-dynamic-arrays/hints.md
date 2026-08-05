`len` is how many elements are there. `cap` is how many would fit before the
array has to move.

They are different numbers, and printing one when you meant the other is a real
mistake that the output alone will not always catch — the allocator reserves
room in steps, so a capacity can happen to equal the length you wanted.

The OBJECTS panel shows the length in brackets, and lists exactly that many
elements.
