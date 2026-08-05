import gdb, json
gdb.execute("set confirm off"); gdb.execute("set pagination off")
ESPERADO=[0,1,1,2,3,5,8,13,21]
registros=[]      # (chave, n)
resultados=[]     # (chave, n, retorno)

class FB(gdb.FinishBreakpoint):
    def __init__(s, fr, chave, n):
        super().__init__(fr, internal=True); s.chave=chave; s.n=n
    def stop(s):
        try: rv=int(s.return_value)
        except Exception: rv=None
        resultados.append((s.chave, s.n, rv))
        return False          # nao para: deixa correr
    def out_of_scope(s):
        resultados.append((s.chave, s.n, "fora-de-escopo"))

class BP(gdb.Breakpoint):
    def stop(s):
        fr=gdb.selected_frame()
        try: n=int(fr.read_var("n"))
        except Exception: n=None
        older=fr.older()
        chave=(hex(older.pc()), hex(int(older.read_register("sp")))) if older else None
        registros.append((chave,n))
        try: FB(fr, chave, n)
        except Exception: pass
        return False          # nao para

BP("main::fib")
gdb.execute("run", to_string=True)

pares=[(c,n,r) for (c,n,r) in resultados if isinstance(r,int)]
mentiras=[(c,n,r) for (c,n,r) in pares if not (0<=n<len(ESPERADO)) or r!=ESPERADO[n]]
chaves=set(c for c,_ in registros)
# chaves distintas para as duas chamadas na mesma linha?
por_pc={}
for c,n in registros:
    if c: por_pc.setdefault(c[0],set()).add(c[1])
print("PROBE_JSON_E "+json.dumps({
 "invocacoes": len(registros),
 "retornos_observados": len(pares),
 "fora_de_escopo": sum(1 for _,_,r in resultados if r=="fora-de-escopo"),
 "retornos_errados": len(mentiras),
 "amostra": [(n,r) for _,n,r in pares[:12]],
 "chaves_distintas": len(chaves),
 "call_sites_distintos": len(por_pc),
 "sps_por_call_site": {k:len(v) for k,v in list(por_pc.items())},
}))
