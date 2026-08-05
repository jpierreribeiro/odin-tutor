import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("break antilie.odin:50", to_string=True)   # the fmt.println: everything above is live
gdb.execute("run", to_string=True)
f=gdb.selected_frame()
def sl(n):
    v=f.read_var(n); return int(v["data"]), int(v["len"])

# two-empty-slices: are they distinguishable?
try:
    d1,list1=sl("empty1"); d2,list2=sl("empty2")
    a1=int(f.read_var("empty1").address); a2=int(f.read_var("empty2").address)
    rec("two-empty-slices", a1!=a2, "data=%s/%s len=%d/%d — the VARIABLES' addresses differ: %s"%(hex(d1),hex(d2),list1,list2,a1!=a2))
except Exception as e: rec("two-empty-slices",False,e)

# two-equal-lists: distinct storage?
try:
    da,la=sl("list1"); db,lb=sl("list2")
    rec("two-equal-lists", da!=db, "equal contents, data %s vs %s -> distinct: %s"%(hex(da),hex(db),da!=db))
except Exception as e: rec("two-equal-lists",False,e)

# cycle
try:
    c=f.read_var("cycle_node"); target=int(c); next=int(c.dereference()["next"])
    rec("cycle", target==next, "node=%s  node.next=%s  points at itself: %s"%(hex(target),hex(next),target==next))
except Exception as e: rec("cycle",False,e)

# dynamic array e map
try:
    d=f.read_var("numbers"); fields=[x.name for x in d.type.strip_typedefs().fields()]
    n=int(d["len"]); cap=int(d["cap"])
    el=d["data"].cast(d["data"].type.target().array(n-1).pointer()).dereference()
    rec("dynamic-array", n==2 and [int(el[i]) for i in range(n)]==[10,20],
        "fields=%s len=%d cap=%d vals=%s"%(fields,n,cap,[int(el[i]) for i in range(n)]))
except Exception as e: rec("dynamic-array",False,e)
try:
    m=f.read_var("table"); t=m.type.strip_typedefs()
    rec("map-shape", True, "type=%s fields=%s"%(t, [x.name for x in t.fields()]))
except Exception as e: rec("map-shape",False,e)

# dangling: does reading after free crash, or return garbage?
try:
    mo=f.read_var("dead"); end=int(mo)
    val=int(mo.dereference())
    rec("dangling-pointer", True, "pointer=%s reading AFTER free returned %d with no error - there is no signal, only the value"%(hex(end),val))
except gdb.MemoryError as e:
    rec("dangling-pointer", True, "catchable MemoryError: %s"%e)
except Exception as e: rec("dangling-pointer",False,e)

# a genuinely invalid pointer
try:
    p=gdb.Value(0xdeadbeef).cast(gdb.lookup_type("int").pointer())
    v=int(p.dereference()); rec("invalid-pointer", False, "read %s from 0xdeadbeef?!"%v)
except gdb.MemoryError as e:
    rec("invalid-pointer", True, "gdb.MemoryError — catchable, does not bring the process down: %s"%e)
except Exception as e: rec("invalid-pointer", True, "catchable exception: %r"%e)

# corrupt length
try:
    d,l=sl("corrupted")
    rec("corrupt-length", l>1_000_000, "len read = %d (the adapter MUST refuse before reading)"%l)
except Exception as e: rec("corrupt-length",False,e)

# free-then-allocate: same address?
try:
    second=int(f.read_var("second"))
    rec("free-then-allocate", True, "second=%s (p1 already freed; address reuse is the R-07 case)"%hex(second))
except Exception as e: rec("free-then-allocate",False,e)

# utf8: len in bytes
try:
    s=f.read_var("text"); n=int(s["len"])
    b=bytes(int(s["data"][i]) for i in range(n))
    rec("prints-utf8", n!=len(b.decode()), "len=%d bytes, %d characters - the units DIFFER"%(n,len(b.decode())))
except Exception as e: rec("prints-utf8",False,e)
print("ANTILIE_JSON "+json.dumps(R))
