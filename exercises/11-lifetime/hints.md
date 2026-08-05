`free(node)` gives the memory back. It does not change `node`, which still
holds the address it held before.

Watch the FRAMES panel across the free: the slot does not change. That is the
lesson, and it is uncomfortable — the tool cannot show you a dangling pointer,
because a freed region stays mapped and reads back as an ordinary number.

`node = nil` writes the fact down. After it, the picture says `nil` instead of
pointing at something that is gone.
