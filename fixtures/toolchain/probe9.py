import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
vistos=[]
def ao_criar(ev):
    vistos.append(str(ev.inferior_thread.num))
gdb.events.new_thread.connect(ao_criar)

gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
hist=[]
for _ in range(300):
    try:
        sal=gdb.selected_frame().find_sal()
        nome=sal.symtab.filename if sal and sal.symtab else ""
    except gdb.error: break
    if not nome.endswith("threadfix.odin"):
        try: gdb.execute("finish", to_string=True); continue
        except gdb.error: break
    hist.append((sal.line, len(vistos), len(gdb.selected_inferior().threads())))
    if vistos: break
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
rec("evento-new_thread", bool(vistos),
    "threads criadas vistas por evento: %s | historico (linha, eventos, contagem)= %s"%(vistos,hist))
rec("amostragem-vs-evento", True,
    "a contagem por parada nunca passou de %d; o evento pegou %d"%(max([h[2] for h in hist] or [0]), len(vistos)))
print("PROBE_JSON_I "+json.dumps(R))
