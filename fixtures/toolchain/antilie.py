import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("break antilie.odin:40", to_string=True)
gdb.execute("run", to_string=True)
f=gdb.selected_frame()
def sl(n):
    v=f.read_var(n); return int(v["data"]), int(v["len"])

# two-empty-slices: distinguiveis?
try:
    d1,l1=sl("vazia1"); d2,l2=sl("vazia2")
    a1=int(f.read_var("vazia1").address); a2=int(f.read_var("vazia2").address)
    rec("two-empty-slices", a1!=a2, "data=%s/%s len=%d/%d — enderecos DAS VARIAVEIS diferem: %s"%(hex(d1),hex(d2),l1,l2,a1!=a2))
except Exception as e: rec("two-empty-slices",False,e)

# two-equal-lists: armazenamentos distintos?
try:
    da,la=sl("l1"); db,lb=sl("l2")
    rec("two-equal-lists", da!=db, "conteudo igual, data %s vs %s -> distintos: %s"%(hex(da),hex(db),da!=db))
except Exception as e: rec("two-equal-lists",False,e)

# cycle
try:
    c=f.read_var("c"); alvo=int(c); prox=int(c.dereference()["prox"])
    rec("cycle", alvo==prox, "no=%s  no.prox=%s  aponta para si: %s"%(hex(alvo),hex(prox),alvo==prox))
except Exception as e: rec("cycle",False,e)

# dynamic array e map
try:
    d=f.read_var("din"); campos=[x.name for x in d.type.strip_typedefs().fields()]
    n=int(d["len"]); cap=int(d["cap"])
    el=d["data"].cast(d["data"].type.target().array(n-1).pointer()).dereference()
    rec("dynamic-array", n==2 and [int(el[i]) for i in range(n)]==[10,20],
        "campos=%s len=%d cap=%d vals=%s"%(campos,n,cap,[int(el[i]) for i in range(n)]))
except Exception as e: rec("dynamic-array",False,e)
try:
    m=f.read_var("m"); t=m.type.strip_typedefs()
    rec("map-shape", True, "tipo=%s campos=%s"%(t, [x.name for x in t.fields()]))
except Exception as e: rec("map-shape",False,e)

# dangling: ler apos free crasha ou devolve lixo?
try:
    mo=f.read_var("morto"); end=int(mo)
    val=int(mo.dereference())
    rec("dangling-pointer", True, "ponteiro=%s leitura APOS free devolveu %d sem erro — nao ha sinal, so o valor"%(hex(end),val))
except gdb.MemoryError as e:
    rec("dangling-pointer", True, "MemoryError capturavel: %s"%e)
except Exception as e: rec("dangling-pointer",False,e)

# ponteiro invalido de verdade
try:
    p=gdb.Value(0xdeadbeef).cast(gdb.lookup_type("int").pointer())
    v=int(p.dereference()); rec("ponteiro-invalido", False, "leu %s de 0xdeadbeef?!"%v)
except gdb.MemoryError as e:
    rec("ponteiro-invalido", True, "gdb.MemoryError — capturavel, nao derruba o processo: %s"%e)
except Exception as e: rec("ponteiro-invalido", True, "excecao capturavel: %r"%e)

# corrupt length
try:
    d,l=sl("corrompida")
    rec("corrupt-length", l>1_000_000, "len lido = %d (o adaptador DEVE recusar antes de ler)"%l)
except Exception as e: rec("corrupt-length",False,e)

# free-then-allocate: mesmo endereco?
try:
    p2=int(f.read_var("p2"))
    rec("free-then-allocate", True, "p2=%s (p1 ja liberado; reuso de endereco e o caso do R-07)"%hex(p2))
except Exception as e: rec("free-then-allocate",False,e)

# utf8: len em bytes
try:
    s=f.read_var("txt"); n=int(s["len"])
    b=bytes(int(s["data"][i]) for i in range(n))
    rec("prints-utf8", n!=len(b.decode()), "len=%d bytes, %d caracteres — unidades DIFEREM"%(n,len(b.decode())))
except Exception as e: rec("prints-utf8",False,e)
print("ANTILIE_JSON "+json.dumps(R))
