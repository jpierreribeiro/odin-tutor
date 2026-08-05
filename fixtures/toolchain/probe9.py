import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
seen=[]
def on_new_thread(ev):
    seen.append(str(ev.inferior_thread.num))
gdb.events.new_thread.connect(on_new_thread)

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
    history.append((sal.line, len(seen), len(gdb.selected_inferior().threads())))
    if seen: break
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
rec("new_thread-event", bool(seen),
    "threads created, seen by event: %s | history (line, events, count)= %s"%(seen,history))
rec("sampling-vs-event", True,
    "the per-stop count never rose above %d; the event caught %d"%(max([h[2] for h in history] or [0]), len(seen)))
print("PROBE_JSON_I "+json.dumps(R))
