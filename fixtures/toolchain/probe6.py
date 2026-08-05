import gdb, json, time
gdb.execute("set confirm off"); gdb.execute("set pagination off")
FONTE="fixture.odin"
gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
passos=0; saltos=0; t0=time.time()
while passos < 400:
    try:
        sal=gdb.selected_frame().find_sal()
        nome=sal.symtab.filename if sal and sal.symtab else ""
    except gdb.error: break
    if not nome.endswith(FONTE):
        try: gdb.execute("finish", to_string=True); saltos+=1; continue
        except gdb.error: break
    passos+=1
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
dt=time.time()-t0
print("PROBE_JSON_F "+json.dumps({
 "passos_do_estudante": passos, "saidas_por_finish": saltos,
 "ms_por_passo_do_estudante": round(dt/max(1,passos)*1000,2),
 "total_s": round(dt,2)}))
