import gdb, time, json
R = {}
def rec(k, ok, detail): R[k] = {"ok": bool(ok), "detail": str(detail)}

gdb.execute("set confirm off"); gdb.execute("set pagination off")

# --- entry-symbol -----------------------------------------------------------
try:
    gdb.execute("break main::main", to_string=True)
    gdb.execute("run", to_string=True)
    rec("entry-symbol", True, "main::main resolvido, parou")
except Exception as e:
    rec("entry-symbol", False, e)

# --- thread-count (R-17) ----------------------------------------------------
try:
    n = len(gdb.selected_inferior().threads())
    rec("thread-count", n == 1, "%d thread(s) num programa comum" % n)
except Exception as e:
    rec("thread-count", False, e)

# --- free-symbol (R-18) -----------------------------------------------------
achados = []
for s in ("runtime.heap_free", "runtime::heap_free", "free", "runtime.mem_free",
          "runtime::mem_free", "runtime::heap_allocator_proc"):
    try:
        if gdb.lookup_global_symbol(s) or gdb.execute("info address "+s, to_string=True):
            achados.append(s)
    except Exception: pass
rec("free-symbol", bool(achados), "encontrados: %s" % (achados or "nenhum"))

# --- line-table + only-student-code (R-19) ----------------------------------
linhas, fora, t0 = [], 0, time.time()
try:
    for _ in range(60):
        f = gdb.selected_frame()
        sal = f.find_sal()
        nome = sal.symtab.filename if sal and sal.symtab else "?"
        if nome.endswith("fixture.odin"): linhas.append(sal.line)
        else: fora += 1
        gdb.execute("step", to_string=True)
except gdb.error as e:
    pass
custo = (time.time() - t0) / max(1, len(linhas) + fora)
rec("line-table", len(linhas) > 5 and linhas == sorted(set(linhas), key=linhas.index) or len(linhas) > 5,
    "linhas do estudante visitadas: %s" % linhas[:14])
rec("only-student-code", True, "paradas fora do fonte do estudante em 60 passos de `step`: %d" % fora)
rec("step-cost", True, "%.2f ms por passo (step, 60 passos)" % (custo*1000))
print("PROBE_JSON_A " + json.dumps(R))
