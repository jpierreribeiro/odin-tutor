`proc(a: int, b: int) -> (int, bool)` returns two values, and the caller writes
`result, ok := divide(...)`.

The FRAMES panel shows both as slots side by side. Watch what `ok` holds when
`b` is zero: `false` means the number beside it means nothing, and the caller
must not use it.

Returning `0, true` prints a zero the student will believe. That is the failure
this tool exists to make visible.
