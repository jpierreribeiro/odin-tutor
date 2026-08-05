import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")

# why is return_value None?
gdb.execute("break main::fib", to_string=True)
gdb.execute("run", to_string=True)
fr=gdb.selected_frame()
fn=fr.function()
rec("return-type", fn is not None and fn.type is not None,
    "function()=%s  type=%s  target=%s"%(fn, fn.type if fn else None,
      (fn.type.target() if fn and fn.type else None)))

class FB(gdb.FinishBreakpoint):
    def __init__(s,f): super().__init__(f,internal=True); s.rv=None; s.rax=None; s.error=None
    def stop(s):
        try: s.rv = s.return_value
        except Exception as e: s.error=repr(e)
        try: s.rax = int(gdb.selected_frame().read_register("rax"))
        except Exception as e: pass
        return True
fb=FB(gdb.selected_frame()); arg=int(fr.read_var("n"))
gdb.execute("continue", to_string=True)
rec("finish-return-value", fb.rv is not None, "return_value=%s error=%s"%(fb.rv,fb.error))
expected=[0,1,1,2,3,5,8,13,21][arg]
rec("return-via-rax", fb.rax==expected,
    "fib(%d): rax=%s expected=%s -> %s"%(arg,fb.rax,expected,"MATCHES" if fb.rax==expected else "no"))

# which stops land outside the student's source?
gdb.execute("delete", to_string=True)
gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
outside={}
for _ in range(120):
    try:
        sal=gdb.selected_frame().find_sal()
        name=sal.symtab.filename if sal and sal.symtab else "<no symtab>"
        if not name.endswith("fixture.odin"):
            outside[name]=outside.get(name,0)+1
        gdb.execute("step", to_string=True)
    except gdb.error: break
rec("only-student-code", True, "files outside the source over 120 `step`s: %s"%(outside or "none"))
print("PROBE_JSON_C "+json.dumps(R))
