import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
counts=[]
for _ in range(200):
    n=len(gdb.selected_inferior().threads())
    counts.append(n)
    if n>1: break
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
rec("spawns-thread-detectable", max(counts)>1,
    "steps until detected: %d  final count: %d"%(len(counts), counts[-1]))
print("PROBE_JSON_G "+json.dumps(R))
