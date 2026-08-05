An Odin string is a pointer and a length, exactly like a slice — the length is
stored beside the data, not marked by a zero byte at the end.

In the OBJECTS panel a string shows its text and its length in BYTES. Reaching
`len(name)` reads that number; it does not walk the characters.

That is why `16-utf8` is a different exercise: the number is bytes, and bytes are
not characters.

One wrinkle you will see: the debugger reports a string as `struct string`,
because that is what it is underneath — a pointer and a length in a struct. The
tool shows what the debug information says rather than tidying it, and the
tidied name would hide exactly the fact this exercise is about.

A note for whoever writes the next version of this exercise. Its first wrong
solution built the bytes by hand and converted them with `string(letters[:])`.
That produces a REAL string — same type, same length, same output — so the
exercise accepted it, correctly. A wrong solution has to be wrong.
