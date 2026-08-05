Recursion means the procedure calls itself, and each call gets its own frame.

Step forward and watch the FRAMES panel grow: `countdown()` above `countdown()`
above `main()`, each with a different `n`. A loop keeps one frame and changes
one `n`.

The base case is the whole point. When `n` reaches zero the innermost call
returns 0, and every call above it adds one. A loop can print the same number
and never have that frame at all.
