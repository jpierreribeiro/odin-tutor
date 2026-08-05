A slice is a pointer and a length, side by side.

`[]int{7}` builds a one-element slice, so `length_of` is 1. The exercise wants
three. Add them to the literal.

In the OBJECTS panel the slice shows its length in brackets and then its
elements. Those elements are read from memory, not from the text you wrote.
