import gdb, json, time
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("break fixture.odin:29", to_string=True)   # depois de sub := notas[1:]
gdb.execute("run", to_string=True)

f=gdb.selected_frame()
# --- struct-fields ---
try:
    a=f.read_var("a"); t=a.type.strip_typedefs()
    campos=[fld.name for fld in t.fields()]
    nome=a["nome"]; idade=int(a["idade"])
    rec("struct-fields", campos==["nome","notas","idade"] and idade==20,
        "campos=%s idade=%d nome.len=%d" % (campos,idade,int(nome["len"])))
except Exception as e: rec("struct-fields",False,e)

# --- slice-fields + leitura de elementos ---
try:
    notas=f.read_var("notas"); sub=f.read_var("sub")
    d1,l1=int(notas["data"]),int(notas["len"])
    d2,l2=int(sub["data"]),int(sub["len"])
    elem=notas["data"].type.target()
    arr=notas["data"].cast(elem.array(l1-1).pointer()).dereference()
    vals=[int(arr[i]) for i in range(l1)]
    rec("slice-fields", l1==3 and l2==2 and vals==[7,8,9] and d2>d1,
        "notas={len:%d vals:%s} sub={len:%d} sub.data-notas.data=%d bytes  (armazenamento compartilhado, deslocado)"%(l1,vals,l2,d2-d1))
except Exception as e: rec("slice-fields",False,e)

# --- string por valor ---
try:
    s=f.read_var("a")["nome"]
    n=int(s["len"]); ptr=s["data"]
    txt=bytes(int(ptr[i]) for i in range(n)).decode()
    rec("string-value", txt=="Ana", 'lida como "%s" (len=%d)'%(txt,n))
except Exception as e: rec("string-value",False,e)

# --- frame-key (R-04): caller pc + sp em profundidade >= 2, estabilidade ---
gdb.execute("delete", to_string=True)
gdb.execute("break main::fib", to_string=True)
gdb.execute("run", to_string=True)
for _ in range(4): gdb.execute("continue", to_string=True)
try:
    fr=gdb.selected_frame(); prof=0; ch=[]
    while fr and prof<8:
        older=fr.older()
        ch.append((str(fr.name()), hex(fr.pc()), hex(int(fr.read_register("sp")))))
        fr=older; prof+=1
    cur=gdb.selected_frame(); older=cur.older()
    chave1=(older.pc(), int(older.read_register("sp")))
    gdb.execute("next", to_string=True)
    cur2=gdb.selected_frame(); older2=cur2.older()
    chave2=(older2.pc(), int(older2.read_register("sp")))
    rec("frame-key", chave1==chave2 and prof>=2,
        "profundidade=%d  chave(caller pc,sp)=(%s,%s) estável após um passo: %s"%(prof,hex(chave1[0]),hex(chave1[1]),chave1==chave2))
    rec("frame-walk", prof>=3, "pilha: %s"%[c[0] for c in ch])
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
    esperado=[0,1,1,2,3,5,8,13][arg] if 0<=arg<8 else None
    rec("finish-breakpoint", fb.got is not None,
        "fib(%s) retornou %s (esperado %s) — %s"%(arg,fb.got,esperado,"confere" if fb.got==esperado else "NAO CONFERE"))
except Exception as e: rec("finish-breakpoint",False,e)
print("PROBE_JSON_B "+json.dumps(R))
