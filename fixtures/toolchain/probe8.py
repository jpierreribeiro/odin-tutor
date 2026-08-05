import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("set non-stop off", to_string=True)
# para na linha DEPOIS da criacao da thread
gdb.execute("break threadfix.odin:10", to_string=True)   # c := b + 1
gdb.execute("run", to_string=True)
n=len(gdb.selected_inferior().threads())
rec("thread-apos-criacao", n>1, "threads na linha seguinte a create_and_start: %d"%n)

# agora um laco confinado ao fonte do estudante, contando threads a cada passo
gdb.execute("delete", to_string=True)
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
    hist.append((sal.line, len(gdb.selected_inferior().threads())))
    if hist[-1][1] > 1: break
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
rec("deteccao-no-laco-confinado", hist and hist[-1][1] > 1,
    "(linha, threads) = %s"%hist)
print("PROBE_JSON_H "+json.dumps(R))
