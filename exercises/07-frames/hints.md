Calling `add(3, 4)` puts a second frame above `main` in the FRAMES panel, with
its own `a` and `b`.

Watch the moment it returns: the frame shows `returned 7`, attributed to that
exact invocation and to no other. Doing the arithmetic in `main` prints the same
number and never creates the frame.
