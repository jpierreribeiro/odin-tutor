	Guardado :: union {
		int,
		string,
	}

	guardado: Guardado = 42
	numero, e_numero := guardado.(int)

The second line is a type assertion. It returns the value and whether the union
really held that variant — the same "value and whether it is real" shape you met
in `20-errors`.

In the OBJECTS panel a union shows ONE member, named by the type it is holding:

	[2] union main::Guardado
	    int = 42

Assign a string to it and that line reads `string = ...` instead. There is no
state in which it shows both, which is exactly what a struct with a flag cannot
promise.
