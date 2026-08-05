import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
extras=[]
def ao_criar(ev):
    t=ev.inferior_thread
    if t.num != 1: extras.append(t.num)      # 1 = thread principal
gdb.events.new_thread.connect(ao_criar)

gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
hist=[]; parou_em=None
for _ in range(300):
    try:
        sal=gdb.selected_frame().find_sal()
        nome=sal.symtab.filename if sal and sal.symtab else ""
    except gdb.error: break
    if not nome.endswith("threadfix.odin"):
        try: gdb.execute("finish", to_string=True); continue
        except gdb.error: break
    if extras: parou_em=sal.line; break
    hist.append(sal.line)
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
rec("evento-detecta-thread-do-estudante", bool(extras),
    "threads extras: %s | passos gravados antes de parar: %s | parou na linha %s"%(extras,hist,parou_em))
print("PROBE_JSON_J "+json.dumps(R))
