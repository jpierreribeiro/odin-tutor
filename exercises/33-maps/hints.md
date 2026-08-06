	vistos := make(map[string]bool)
	defer delete(vistos)
	vistos["ana"] = true

A map is keyed. Writing a key it already holds replaces the value; it does not
add a second entry. That is why `len` is the count of DISTINCT keys and you do
not have to search before inserting.

In the FRAMES panel a map reads like this:

	vistos (2 entries) ? unknown (map entries are not readable ...)

The count is measured and the entries are not: this tool will not decode a
layout no type describes, so it tells you how many rather than guessing what
([ADR-014](../../docs/decisions/ADR-014-maps-are-counted-not-walked.md)).

For this exercise the count is the whole lesson.
