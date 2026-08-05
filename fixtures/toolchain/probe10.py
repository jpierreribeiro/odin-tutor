import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
extra=[]
def on_new_thread(ev):
    t=ev.inferior_thread
    if t.num != 1: extra.append(t.num)      # 1 = the main thread
gdb.events.new_thread.connect(on_new_thread)

gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
history=[]; stopped_at=None
for _ in range(300):
    try:
        sal=gdb.selected_frame().find_sal()
        name=sal.symtab.filename if sal and sal.symtab else ""
    except gdb.error: break
    if not name.endswith("threadfix.odin"):
        try: gdb.execute("finish", to_string=True); continue
        except gdb.error: break
    if extra: stopped_at=sal.line; break
    history.append(sal.line)
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
rec("event-detects-student-thread", bool(extra),
    "extra threads: %s | steps recorded before stopping: %s | stopped at line %s"%(extra,history,stopped_at))
print("PROBE_JSON_J "+json.dumps(R))
