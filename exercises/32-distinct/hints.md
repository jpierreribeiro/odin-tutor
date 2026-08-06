	User_Id :: distinct int

Without `distinct`, `User_Id` is another spelling of `int` — the compiler sees
one type and will let an age be used as an id forever.

With it, `User_Id` is a new type that happens to be stored the same way. Same
size, same bytes, same printed `7`. What changed is what the compiler will
accept, and that is invisible to every test that reads output.

In the FRAMES panel, a named type is shown and a builtin is not:

	id: main::User_Id = 7
	idade = 7

Two variables holding the same number, and the screen says they are not the
same kind of thing.
