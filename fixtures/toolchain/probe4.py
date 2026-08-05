import gdb, json
R={}
def rec(k,ok,d): R[k]={"ok":bool(ok),"detail":str(d)}
gdb.execute("set confirm off"); gdb.execute("set pagination off")
gdb.execute("break main::soma", to_string=True)   # nao-recursivo primeiro
gdb.execute("run", to_string=True)

log={}
class FB(gdb.FinishBreakpoint):
    def __init__(s,f): super().__init__(f,internal=True)
    def stop(s):
        log["disparou"]=True
        try: log["return_value"]=str(s.return_value)
        except Exception as e: log["rv_erro"]=repr(e)
        try:
            fr=gdb.selected_frame()
            log["rax"]=int(fr.read_register("rax"))
        except Exception as e: log["rax_erro"]=repr(e)
        return True
    def out_of_scope(s): log["fora_de_escopo"]=True

FB(gdb.selected_frame())
gdb.execute("continue", to_string=True)
rec("soma-retorno", log.get("rax")==24 or log.get("return_value")=="24", json.dumps(log))

# agora com `finish` puro, que imprime o valor
gdb.execute("delete", to_string=True)
gdb.execute("break main::soma", to_string=True)
gdb.execute("run", to_string=True)
saida=gdb.execute("finish", to_string=True)
rec("finish-textual", "24" in saida, saida.strip().replace("\n"," | ")[-160:])
print("PROBE_JSON_D "+json.dumps(R))
