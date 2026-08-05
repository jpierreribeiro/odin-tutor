import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("set non-stop off", to_string=True)
# stop on the line AFTER the thread is created
gdb.execute("break threadfix.odin:9", to_string=True)   # c := b + 1
gdb.execute("run", to_string=True)
n=len(gdb.selected_inferior().threads())
rec("thread-after-creation", n>1, "threads on the line after create_and_start: %d"%n)

# now a loop confined to the student's source, counting threads at each stop
gdb.execute("delete", to_string=True)
gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
history=[]
for _ in range(300):
    try:
        sal=gdb.selected_frame().find_sal()
        name=sal.symtab.filename if sal and sal.symtab else ""
    except gdb.error: break
    if not name.endswith("threadfix.odin"):
        try: gdb.execute("finish", to_string=True); continue
        except gdb.error: break
    history.append((sal.line, len(gdb.selected_inferior().threads())))
    if history[-1][1] > 1: break
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
rec("detection-in-confined-loop", history and history[-1][1] > 1,
    "(line, threads) = %s"%history)
print("PROBE_JSON_H "+json.dumps(R))
