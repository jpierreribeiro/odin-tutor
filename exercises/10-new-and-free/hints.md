`new(Node)` returns a `^Node` — a pointer to memory that outlives the line it
was written on. `Node{...}` is a local, and it dies with the procedure.

In FRAMES a pointer shows `node -> [2]`; a local struct shows its fields
directly.

`free(node)` gives it back. Watch what happens to the object's number after
that: the next allocation at the same address gets a NEW number, because the
tool records that the old one died.
