	pontos: #soa[2]Ponto

That is the only edit. Indexing, assignment and printing are written exactly as
they were.

In the OBJECTS panel, look at what `pontos` is made of. An `[2]Ponto` holds two
`Ponto` objects, each with its own `x` and `y`. A `#soa[2]Ponto` holds two
FIELDS — `x` and `y` — and each of those is an array of two.

So `pontos.x[0]` and `pontos.x[1]` sit side by side in memory. Nothing about
your code says so; only the arrangement does.
