	trocado := ordem.zyx

`x`, `y`, `z`, `w` name the first four elements of a small array, and `r`, `g`,
`b`, `a` name the same slots. Writing them in any order builds a new array in
that order — `ordem.zyx` is the reverse, and `ordem.xx` is a two-element array
holding the first element twice.

The result is a NEW array. `ordem` is untouched, which the picture shows as two
separate objects: read all three elements of each. A half-finished reversal
leaves one of them holding a number that came from the wrong place, and a
program printing a single element will never show it.
