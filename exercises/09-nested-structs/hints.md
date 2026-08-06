A field's type can be another struct:

	Casa :: struct {
		canto: Ponto,
		lado:  int,
	}

Then the value is written `Casa{canto = Ponto{x = 3, y = 4}, lado = 10}` and
read as `casa.canto.x`.

In the OBJECTS panel this is one entry nested inside another, and `casa` has TWO
fields rather than three. Grouping is not decoration: it is the difference
between "these two numbers are a point" and "these two numbers have similar
names".
