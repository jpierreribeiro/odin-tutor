	total :: proc(nums: ..int) -> int

The `..` is the whole change. The caller keeps writing `total(1, 2, 3)`, and
inside the procedure `nums` is a slice holding those three numbers.

In the picture, `nums` points at a slice — `nums -> [3]` — and the OBJECTS panel
shows that slice with its length and its elements. That length is the
count of arguments the caller wrote, which is a fact the printed answer does not
carry.
