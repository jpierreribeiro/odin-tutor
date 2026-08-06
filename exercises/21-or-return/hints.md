	v := primeiro(xs) or_return

That one line means: call it, and if the last returned value is not nil, return
it from HERE, right now. Otherwise carry on with the value.

It is the same as writing

	v, e := primeiro(xs)
	if e != nil {
		err = e
		return
	}

which is why the results have to be named — the bare `return` needs somewhere to
put the error.

In the FRAMES panel, look at `err` in `main` after the call. `Empty` means the
answer beside it means nothing. `None` beside a zero means the program is
telling you something it does not know.
