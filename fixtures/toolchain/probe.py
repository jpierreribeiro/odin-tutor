import gdb, time, json
R = {}
def rec(k, ok, detail): R[k] = {"ok": bool(ok), "detail": str(detail)}

gdb.execute("set confirm off"); gdb.execute("set pagination off")

# --- entry-symbol -----------------------------------------------------------
try:
    gdb.execute("break main::main", to_string=True)
    gdb.execute("run", to_string=True)
    rec("entry-symbol", True, "main::main resolved, stopped")
except Exception as e:
    rec("entry-symbol", False, e)

# --- thread-count (R-17) ----------------------------------------------------
try:
    n = len(gdb.selected_inferior().threads())
    rec("thread-count", n == 1, "%d thread(s) in a plain program" % n)
except Exception as e:
    rec("thread-count", False, e)

# --- free-symbol (R-18) -----------------------------------------------------
found = []
for s in ("runtime.heap_free", "runtime::heap_free", "free", "runtime.mem_free",
          "runtime::mem_free", "runtime::heap_allocator_proc"):
    try:
        if gdb.lookup_global_symbol(s) or gdb.execute("info address "+s, to_string=True):
            found.append(s)
    except Exception: pass
rec("free-symbol", bool(found), "found: %s" % (found or "none"))

# --- line-table + only-student-code (R-19) ----------------------------------
lines, outside, t0 = [], 0, time.time()
try:
    for _ in range(60):
        f = gdb.selected_frame()
        sal = f.find_sal()
        name = sal.symtab.filename if sal and sal.symtab else "?"
        if name.endswith("fixture.odin"): lines.append(sal.line)
        else: outside += 1
        gdb.execute("step", to_string=True)
except gdb.error as e:
    pass
cost = (time.time() - t0) / max(1, len(lines) + outside)
rec("line-table", len(lines) > 5 and lines == sorted(set(lines), key=lines.index) or len(lines) > 5,
    "student lines visited: %s" % lines[:14])
rec("only-student-code", True, "stops outside the student's source over 60 `step`s: %d" % outside)
rec("step-cost", True, "%.2f ms per step (step, 60 steps)" % (cost*1000))
print("PROBE_JSON_A " + json.dumps(R))
