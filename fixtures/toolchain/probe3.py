import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")

# por que return_value e None?
gdb.execute("break main::fib", to_string=True)
gdb.execute("run", to_string=True)
fr=gdb.selected_frame()
fn=fr.function()
rec("tipo-de-retorno", fn is not None and fn.type is not None,
    "function()=%s  type=%s  target=%s"%(fn, fn.type if fn else None,
      (fn.type.target() if fn and fn.type else None)))

class FB(gdb.FinishBreakpoint):
    def __init__(s,f): super().__init__(f,internal=True); s.rv=None; s.rax=None; s.erro=None
    def stop(s):
        try: s.rv = s.return_value
        except Exception as e: s.erro=repr(e)
        try: s.rax = int(gdb.selected_frame().read_register("rax"))
        except Exception as e: pass
        return True
fb=FB(gdb.selected_frame()); arg=int(fr.read_var("n"))
gdb.execute("continue", to_string=True)
rec("finish-return-value", fb.rv is not None, "return_value=%s erro=%s"%(fb.rv,fb.erro))
esperado=[0,1,1,2,3,5,8,13,21][arg]
rec("retorno-via-rax", fb.rax==esperado,
    "fib(%d): rax=%s esperado=%s -> %s"%(arg,fb.rax,esperado,"CONFERE" if fb.rax==esperado else "nao"))

# quais paradas caem fora do fonte do estudante?
gdb.execute("delete", to_string=True)
gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
fora={}
for _ in range(120):
    try:
        sal=gdb.selected_frame().find_sal()
        nome=sal.symtab.filename if sal and sal.symtab else "<sem symtab>"
        if not nome.endswith("fixture.odin"):
            fora[nome]=fora.get(nome,0)+1
        gdb.execute("step", to_string=True)
    except gdb.error: break
rec("only-student-code", True, "arquivos fora do fonte em 120 `step`: %s"%(fora or "nenhum"))
print("PROBE_JSON_C "+json.dumps(R))
