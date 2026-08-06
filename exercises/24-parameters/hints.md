	dobrar :: proc(n: ^int) {
		n^ *= 2
	}

	dobrar(&total)

`^int` is "a pointer to an int". `&total` is the address of the caller's
variable, and `n^` is the thing at that address — which is `total` itself.

In the FRAMES panel you will see two frames while the call runs. Without the
pointer, `dobrar`'s `n` and `main`'s `total` are unrelated slots, and doubling
one leaves the other where it was. With the pointer, `n` reaches across into the
caller's frame.
