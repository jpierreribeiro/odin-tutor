import gdb, json, time
gdb.execute("set confirm off"); gdb.execute("set pagination off")
FONTE="fixture.odin"
gdb.execute("break main::main", to_string=True)
gdb.execute("run", to_string=True)
steps=0; escapes=0; t0=time.time()
while steps < 400:
    try:
        sal=gdb.selected_frame().find_sal()
        name=sal.symtab.filename if sal and sal.symtab else ""
    except gdb.error: break
    if not name.endswith(FONTE):
        try: gdb.execute("finish", to_string=True); escapes+=1; continue
        except gdb.error: break
    steps+=1
    try: gdb.execute("step", to_string=True)
    except gdb.error: break
dt=time.time()-t0
print("PROBE_JSON_F "+json.dumps({
 "passos_do_estudante": steps, "saidas_por_finish": escapes,
 "ms_por_passo_do_estudante": round(dt/max(1,steps)*1000,2),
 "total_s": round(dt,2)}))
