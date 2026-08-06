	visto := texto

That is the whole answer. An Odin string is `{pointer, length}`, so assigning
one copies two numbers.

In the OBJECTS panel, look for `shares with`. One set of bytes carrying two
names is what the assignment produces. `strings.clone` produces two sets, each
with its own name and no mark between them — and the second one is memory you
now have to give back.

Cloning is right when you need to outlive the original or to change it. It is
wrong when all you wanted was to look at it.
