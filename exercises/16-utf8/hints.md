`len` on an Odin string counts BYTES.

`ï` costs two bytes and `✓` costs three, so "naïve ✓" is 7 characters and 10
bytes. Ten ASCII letters are also 10 bytes — the number alone cannot tell you
which you built.

This distinction is not academic: a budget that counted characters against a
byte limit once cut a document in half and lost a whole trace.

In the OBJECTS panel, read the string's bytes one at a time:

	[0] = 110 'n'
	[1] = 97 'a'
	[2] = 195 '\303'
	[3] = 175 '\257'

`ï` is ONE character and TWO bytes, and neither of them is a letter. Ten ASCII
letters also make `len` say 10, and teach none of this.
