import gdb, json
gdb.execute("set confirm off"); gdb.execute("set pagination off")
EXPECTED=[0,1,1,2,3,5,8,13,21]
entries=[]      # (key, n)
results=[]     # (key, n, retorno)

class FB(gdb.FinishBreakpoint):
    def __init__(s, fr, key, n):
        super().__init__(fr, internal=True); s.key=key; s.n=n
    def stop(s):
        try: rv=int(s.return_value)
        except Exception: rv=None
        results.append((s.key, s.n, rv))
        return False          # do not stop: let it run
    def out_of_scope(s):
        results.append((s.key, s.n, "outside-de-escopo"))

class BP(gdb.Breakpoint):
    def stop(s):
        fr=gdb.selected_frame()
        try: n=int(fr.read_var("n"))
        except Exception: n=None
        older=fr.older()
        key=(hex(older.pc()), hex(int(older.read_register("sp")))) if older else None
        entries.append((key,n))
        try: FB(fr, key, n)
        except Exception: pass
        return False          # do not stop

BP("main::fib")
gdb.execute("run", to_string=True)

pairs=[(c,n,r) for (c,n,r) in results if isinstance(r,int)]
lies=[(c,n,r) for (c,n,r) in pairs if not (0<=n<len(EXPECTED)) or r!=EXPECTED[n]]
keys=set(c for c,_ in entries)
# distinct keys for the two calls on one line?
by_pc={}
for c,n in entries:
    if c: by_pc.setdefault(c[0],set()).add(c[1])
print("PROBE_JSON_E "+json.dumps({
 "invocations": len(entries),
 "returns_observed": len(pairs),
 "out_of_scope": sum(1 for _,_,r in results if r=="outside-de-escopo"),
 "wrong_returns": len(lies),
 "sample": [(n,r) for _,n,r in pairs[:12]],
 "distinct_keys": len(keys),
 "distinct_call_sites": len(by_pc),
 "sps_per_call_site": {k:len(v) for k,v in list(by_pc.items())},
}))
