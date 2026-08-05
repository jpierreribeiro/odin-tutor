`[]int{2, 3}` builds a SECOND array that happens to hold the same numbers.
`todos[1:]` builds a window onto the array you already have.

Both print `3 2`. Only the picture tells them apart.

In the OBJECTS panel, look for the words `shares with`. Two entries carrying it
are two windows on one buffer. Two entries without it are two buffers, and
writing through one would not be visible through the other.
