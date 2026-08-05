`len` on an Odin string counts BYTES.

`ï` costs two bytes and `✓` costs three, so "naïve ✓" is 7 characters and 10
bytes. Ten ASCII letters are also 10 bytes — the number alone cannot tell you
which you built.

This distinction is not academic: a budget that counted characters against a
byte limit once cut a document in half and lost a whole trace.
