An enum declares the whole set of values a variable may hold, and each one has
a name:

	Key :: enum { Bronze, Silver, Gold }

Then `held := Key.Silver` is not "the number 1". In the FRAMES panel it reads
`held = Silver`, because the name IS the value.

That is the difference this exercise is about. Both programs print `Silver`.
Only one of them holds it.
