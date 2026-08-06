	soma := a + b

That is the whole program. Fixed arrays of the same type support `+`, `-`, `*`
and `/`, and each one applies to every element.

`soma` is a new array — the addition does not write into `a` or `b`, and there
is no allocation, because a fixed array is a value.

In the OBJECTS panel, read all three elements of `soma`. A loop that stops early
leaves the last one at 0, and a program that prints only the first two will look
correct forever.
