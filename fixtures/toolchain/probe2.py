import gdb, json, time
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("break fixture.odin:30", to_string=True)   # after sub := marks[1:]
gdb.execute("run", to_string=True)

f=gdb.selected_frame()
# --- struct-fields ---
try:
    a=f.read_var("student"); t=a.type.strip_typedefs()
    fields=[fld.name for fld in t.fields()]
    name=a["name"]; age=int(a["age"])
    rec("struct-fields", fields==["name","marks","age"] and age==20,
        "fields=%s age=%d name.len=%d" % (fields,age,int(name["len"])))
except Exception as e: rec("struct-fields",False,e)

# --- slice-fields, and reading the elements ---
try:
    marks=f.read_var("marks"); sub=f.read_var("sub")
    d1,list1=int(marks["data"]),int(marks["len"])
    d2,list2=int(sub["data"]),int(sub["len"])
    elem=marks["data"].type.target()
    arr=marks["data"].cast(elem.array(list1-1).pointer()).dereference()
    vals=[int(arr[i]) for i in range(list1)]
    rec("slice-fields", list1==3 and list2==2 and vals==[7,8,9] and d2>d1,
        "marks={len:%d vals:%s} sub={len:%d} sub.data-marks.data=%d bytes  (shared storage, offset)"%(list1,vals,list2,d2-d1))
except Exception as e: rec("slice-fields",False,e)

# --- string by value ---
try:
    s=f.read_var("student")["name"]
    n=int(s["len"]); ptr=s["data"]
    text=bytes(int(ptr[i]) for i in range(n)).decode()
    rec("string-value", text=="Ana", 'read as "%s" (len=%d)'%(text,n))
except Exception as e: rec("string-value",False,e)

# --- frame-key (R-04): caller pc + sp at depth >= 2, and stability ---
gdb.execute("delete", to_string=True)
gdb.execute("break main::fib", to_string=True)
gdb.execute("run", to_string=True)
for _ in range(4): gdb.execute("continue", to_string=True)
try:
    fr=gdb.selected_frame(); depth=0; ch=[]
    while fr and depth<8:
        older=fr.older()
        ch.append((str(fr.name()), hex(fr.pc()), hex(int(fr.read_register("sp")))))
        fr=older; depth+=1
    cur=gdb.selected_frame(); older=cur.older()
    key_before=(older.pc(), int(older.read_register("sp")))
    gdb.execute("next", to_string=True)
    cur2=gdb.selected_frame(); older2=cur2.older()
    key_after=(older2.pc(), int(older2.read_register("sp")))
    rec("frame-key", key_before==key_after and depth>=2,
        "depth=%d  key(caller pc,sp)=(%s,%s) stable after one step: %s"%(depth,hex(key_before[0]),hex(key_before[1]),key_before==key_after))
    rec("frame-walk", depth>=3, "stack: %s"%[c[0] for c in ch])
except Exception as e: rec("frame-key",False,e)

# --- finish-breakpoint (R-05) ---
try:
    class FB(gdb.FinishBreakpoint):
        def __init__(s,fr): super().__init__(fr,internal=True); s.got=None
        def stop(s):
            s.got=int(s.return_value) if s.return_value is not None else None
            return True
    fr=gdb.selected_frame()
    arg=int(fr.read_var("n"))
    fb=FB(fr)
    gdb.execute("continue", to_string=True)
    expected=[0,1,1,2,3,5,8,13][arg] if 0<=arg<8 else None
    rec("finish-breakpoint", fb.got is not None,
        "fib(%s) returned %s (expected %s) — %s"%(arg,fb.got,expected,"matches" if fb.got==expected else "DOES NOT MATCH"))
except Exception as e: rec("finish-breakpoint",False,e)
print("PROBE_JSON_B "+json.dumps(R))
