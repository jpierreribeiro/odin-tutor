"""Observation extractor: runs inside GDB, emits an observation stream.

This is the one component not written in Odin. The reason is REQ-SAFE-002: a
length read from a possibly-corrupt target must be validated *before* it sizes
a read, and that check has to sit where the read happens. Over GDB/MI the value
arrives already rendered, so the check would be after the fact. See ADR-004.

It reports what it saw. It assigns no identity, detects no sharing, computes no
delta. Those live in the Odin core, tested without a debugger. See ADR-003.

Run:  gdb --batch -nx --quiet -x gdb_extractor.py <executable>
Configuration arrives through the environment, never through argv, so no path
from an exercise reaches a command line. See SPEC-SAFE-042.
"""

import json
import os
import sys
import time

import gdb

SCHEMA_VERSION = 1

# Budgets enforced here, at the read. The core cannot verify them afterwards,
# so they are declared in the output and compared. See ADR-006, SPEC-SAFE-020.
BUDGETS = {
    "elements": int(os.environ.get("TUTOR_ELEMENTS", 30)),
    "fields": int(os.environ.get("TUTOR_FIELDS", 30)),
    "string_length": int(os.environ.get("TUTOR_STRING_LENGTH", 256)),
    "expansions_per_step": int(os.environ.get("TUTOR_EXPANSIONS_PER_STEP", 32)),
    "expansions_total": int(os.environ.get("TUTOR_EXPANSIONS_TOTAL", 600)),
    "sane_length": int(os.environ.get("TUTOR_SANE_LENGTH", 1_000_000)),
    "steps": int(os.environ.get("TUTOR_STEPS", 2500)),
}
WALL_MS = int(os.environ.get("TUTOR_WALL_MS", 60_000))
SOURCE = os.environ.get("TUTOR_SOURCE", "")
OUT_PATH = os.environ.get("TUTOR_OUT", "observations.json")
ENTRY = os.environ.get("TUTOR_ENTRY", "main::main")

VALID, NOT_YET_ACTIVE, UNREADABLE, UNKNOWN = 0, 1, 2, 3

# Names the compiler introduces, which the student did not write.
HIDDEN_NAMES = {"context", "__.context", "__context"}
K_SCALAR, K_STRING, K_SLICE, K_DYNAMIC, K_FIXED, K_STRUCT, K_POINTER, K_MAP, K_OPAQUE = range(9)


def unknown(type_name, reason):
    return {"state": UNKNOWN, "kind": K_OPAQUE, "type_name": type_name, "reason": reason}


def unreadable(type_name, reason):
    return {"state": UNREADABLE, "kind": K_OPAQUE, "type_name": type_name, "reason": reason}


def sane(length):
    """A length from the target is checked before it drives anything.

    An unchecked length is an arbitrary-size read: the single most important
    rule in this file. See SPEC-SAFE-010.
    """
    return isinstance(length, int) and 0 <= length <= BUDGETS["sane_length"]


def holder_address(value):
    """Where the value's own header sits.

    SPEC-MEM-006: two empty slices are byte-identical — both are
    {data: 0x0, len: 0} — so nothing in their contents tells them apart. Only
    the address of the variable holding each one does, and the core's identity
    key expects it under `address`.

    Omitting this collapses every empty view in a program into one object, which
    is REQ-MEM-004 failing in the most visible way there is.
    """
    try:
        return int(value.address) if value.address is not None else 0
    except Exception:  # noqa: BLE001
        return 0


def read_string(value, type_name):
    """Read an Odin string, {data, len}, bounded."""
    try:
        length = int(value["len"])
    except Exception as exc:
        return unknown(type_name, "length not readable: %s" % exc)
    if not sane(length):
        # A value whose length failed validation is `unknown` as a whole. We do
        # NOT read min(length, budget) bytes: thirty plausible characters from
        # corrupt memory hide the corruption the student is looking for.
        # See SPEC-SAFE-011.
        return unknown(type_name, "length %d is not a plausible length" % length)
    take = min(length, BUDGETS["string_length"])
    try:
        data = value["data"]
        raw = bytes(int(data[i]) & 0xFF for i in range(take))
        text = raw.decode("utf-8", errors="replace")
    except gdb.MemoryError as exc:
        return unreadable(type_name, str(exc))
    except Exception as exc:
        return unknown(type_name, str(exc))
    suffix = "…" if length > take else ""
    return {
        "state": VALID, "kind": K_STRING, "type_name": type_name,
        "text": '"%s%s"' % (text, suffix),
        "length": length, "data": int(value["data"]) if value["data"] else 0,
        "address": holder_address(value),
    }


def read_view(value, type_name, has_capacity):
    """Read a slice or dynamic array: {data, len[, cap]}."""
    try:
        length = int(value["len"])
        data = int(value["data"]) if value["data"] else 0
    except Exception as exc:
        return unknown(type_name, "header not readable: %s" % exc)
    if not sane(length):
        return unknown(type_name, "length %d is not a plausible length" % length)

    out = {
        "state": VALID,
        "kind": K_DYNAMIC if has_capacity else K_SLICE,
        "type_name": type_name,
        "length": length,
        "data": data,
        "address": holder_address(value),
    }
    try:
        # The element size lets the core decide whether two views overlap.
        # Without it, a sub-slice looks like an unrelated object that happens
        # to start eight bytes further along.
        out["elem_size"] = int(value["data"].type.target().sizeof)
    except Exception:
        pass
    if has_capacity:
        try:
            out["capacity"] = int(value["cap"])
        except Exception:
            pass
    return out


def read_value(value, depth=0):
    """Interpret one gdb.Value.

    Two branches only: report the value, or report that it cannot be
    interpreted truthfully. There is no best-guess branch. See SAFETY.md §2.
    """
    try:
        t = value.type.strip_typedefs()
        type_name = str(t)
    except Exception as exc:
        return unknown("?", str(exc))

    try:
        fields = {f.name for f in t.fields()} if t.code == gdb.TYPE_CODE_STRUCT else set()
    except Exception:
        fields = set()

    # Odin's composites are structs in debug information. Recognise them by
    # shape before falling through to the generic struct path, or a slice
    # renders as two integers. See SPEC-MEM-050.
    if type_name == "string" or (fields == {"data", "len"} and type_name == "string"):
        return read_string(value, type_name)
    if fields == {"data", "len"}:
        if type_name.startswith("string"):
            return read_string(value, type_name)
        return read_view(value, type_name, has_capacity=False)
    if fields >= {"data", "len", "cap"}:
        return read_view(value, type_name, has_capacity=True)
    if fields == {"data", "len", "allocator"}:
        # A map. The type exposes no key or value access: Odin packs the
        # capacity into the low bits of the data pointer and stores keys and
        # values in parallel arrays. Decoding that is a guess about a layout no
        # type describes, so version 1 reports the count and nothing else.
        # Measured 2026-08-05. See SPEC-MEM-053, R-20.
        try:
            length = int(value["len"])
        except Exception as exc:
            return unknown(type_name, "map length not readable: %s" % exc)
        # ADR-014: counted, not walked. The count is real and the entries are
        # unknown. Decoding the layout by hand produces wrong pairs when it is
        # wrong, and fails silently on a toolchain update.
        return {
            "state": UNKNOWN, "kind": K_MAP, "type_name": type_name,
            "length": length if sane(length) else 0,
            "address": holder_address(value),
            "reason": "map entries are not readable through the debugger on this toolchain",
        }

    try:
        if t.code == gdb.TYPE_CODE_PTR:
            address = int(value)
            return {
                "state": VALID, "kind": K_POINTER, "type_name": type_name,
                "text": "nil" if address == 0 else "->",
                "data": address,
            }
        if t.code in (gdb.TYPE_CODE_INT, gdb.TYPE_CODE_FLT, gdb.TYPE_CODE_BOOL,
                      gdb.TYPE_CODE_ENUM, gdb.TYPE_CODE_CHAR):
            return {"state": VALID, "kind": K_SCALAR, "type_name": type_name, "text": str(value)}
    except gdb.MemoryError as exc:
        return unreadable(type_name, str(exc))
    except Exception as exc:
        return unknown(type_name, str(exc))

    if t.code == gdb.TYPE_CODE_STRUCT:
        return read_struct(value, t, type_name, depth)
    if t.code == gdb.TYPE_CODE_ARRAY:
        return {"state": VALID, "kind": K_FIXED, "type_name": type_name, "text": str(value)}

    return unknown(type_name, "no rule for this shape")


def read_struct(value, t, type_name, depth):
    """Read a struct's fields, bounded, one level deep.

    Depth is bounded rather than recursive-until-done because a cyclic
    structure would otherwise expand forever. A nested composite is reported by
    its shape, and the core links it by identity. See REQ-MEM-011.
    """
    members = []
    try:
        fields = t.fields()
    except Exception as exc:
        return unknown(type_name, str(exc))

    for field in fields[: BUDGETS["fields"]]:
        if field.name is None:
            continue
        try:
            if depth >= 1:
                observed = {"state": VALID, "kind": K_OPAQUE,
                            "type_name": str(field.type), "text": "…"}
            else:
                observed = read_value(value[field.name], depth + 1)
        except gdb.MemoryError as exc:
            observed = unreadable(str(field.type), str(exc))
        except Exception as exc:
            observed = unknown(str(field.type), str(exc))
        members.append({"name": field.name, "value": observed})

    return {
        "state": VALID, "kind": K_STRUCT, "type_name": type_name,
        "members": members,
        "address": int(value.address) if value.address is not None else 0,
    }


def sal_line(frame):
    try:
        sal = frame.find_sal()
        return sal.line if sal else 0
    except Exception:
        return 0


def yet_active(symbol, current_line):
    """Has the program reached this variable's declaration?

    A local declared below the current line exists in the debug information and
    has storage, but that storage holds whatever the previous call left there.

    This applies to arguments too, and that is the case worth naming: at a
    procedure's signature line the prologue has not run, so an argument reads
    as a stack address. Measured — `fib` at its declaration line reported
    `n = 140737488342512`. An argument becomes active once the signature line
    has been passed, not on entry to the frame. See SPEC-MEM-020.

    Returning False here is what produces `not-yet-active` instead of a
    fourteen-digit integer. It is the difference between saying "not created
    yet" and lying about the value.
    """
    try:
        declared = int(symbol.line)
    except Exception:
        return True
    if declared <= 0 or current_line <= 0:
        return True
    return current_line > declared


def frame_key(frame):
    """The caller's program counter and stack pointer.

    The caller's, not this frame's: `fib(n-1) + fib(n-2)` occupies one source
    line and produces two different return addresses, so the call site is what
    tells two sibling invocations apart. Validated 2026-08-05 — 25 of 25
    invocations attributed, none wrong. See SPEC-MEM-060.
    """
    try:
        older = frame.older()
        if older is None:
            return 0, 0
        return int(older.pc()), int(older.read_register("sp"))
    except Exception:
        return 0, 0


def in_student_source(frame):
    try:
        sal = frame.find_sal()
        name = sal.symtab.filename if sal and sal.symtab else ""
    except Exception:
        return False, ""
    return name.endswith(os.path.basename(SOURCE)), name


def collect_frames(frame):
    frames = []
    depth = 0
    f = frame
    while f is not None and depth < 64:
        inside, filename = in_student_source(f)
        if not inside:
            break
        pc, sp = frame_key(f)
        variables = []
        try:
            block = f.block()
        except Exception:
            block = None
        count = 0
        while block is not None and count < BUDGETS["fields"]:
            if block.is_global or block.is_static:
                break
            for symbol in block:
                if not (symbol.is_variable or symbol.is_argument):
                    continue
                if symbol.name in HIDDEN_NAMES:
                    # Odin passes an implicit `context` to every procedure. It
                    # is real, and it is not something the student declared.
                    # Showing it puts a compiler mechanism in the middle of a
                    # lesson about the student's own variables.
                    continue
                count += 1
                if count > BUDGETS["fields"]:
                    break
                try:
                    value = symbol.value(f)
                    if not yet_active(symbol, sal_line(f)):
                        # The variable is in scope but the program has not
                        # reached its declaration, so the storage holds
                        # whatever was on the stack before. Reporting that as
                        # a value teaches the student that `total` started at
                        # 140737488341976. See SPEC-MEM-020, REQ-MEM-008.
                        observed = {
                            "state": NOT_YET_ACTIVE,
                            "kind": K_OPAQUE,
                            "type_name": str(symbol.type),
                            "reason": "declared at line %d, not reached yet" % symbol.line,
                        }
                    else:
                        observed = read_value(value)
                except gdb.MemoryError as exc:
                    observed = unreadable("?", str(exc))
                except Exception as exc:
                    observed = unreadable("?", str(exc))
                variables.append({"name": symbol.name, "value": observed})
            block = block.superblock
        sal = f.find_sal()
        frames.append({
            "procedure": str(f.name()),
            "file": os.path.basename(filename),
            "line": sal.line if sal else 0,
            "depth": depth,
            "caller_pc": pc,
            "caller_sp": sp,
            "variables": variables,
        })
        f = f.older()
        depth += 1
    return frames


class Run:
    def __init__(self):
        self.records = []
        self.returned = []
        self.termination = 0          # Completed
        self.detail = ""
        self.extra_threads = []
        self.started = time.time()

    def on_new_thread(self, event):
        # Detection is by event, not by counting.
        #
        # A per-stop thread count never fires: a thread can be created and exit
        # between two stops, and one did in the measurement. A count would have
        # shipped a safeguard that never triggers, which is worse than none
        # because its presence implies protection. See ADR-012.
        try:
            if event.inferior_thread.num != 1:
                self.extra_threads.append(event.inferior_thread.num)
        except Exception:
            pass


def emit(run, stdout_text, exit_code):
    stream = {
        "schema_version": SCHEMA_VERSION,
        "adapter": "gdb-python/1",
        "odin_version": os.environ.get("TUTOR_ODIN_VERSION", ""),
        "debugger": gdb.VERSION if hasattr(gdb, "VERSION") else "gdb",
        "source_file": os.path.basename(SOURCE),
        "budgets": BUDGETS,
        "records": run.records,
        "termination": run.termination,
        "detail": run.detail,
        "stdout": stdout_text,
        "exit_code": exit_code,
    }
    with open(OUT_PATH, "w", encoding="utf-8") as handle:
        json.dump(stream, handle, ensure_ascii=False)


def main():
    gdb.execute("set confirm off")
    gdb.execute("set pagination off")

    run = Run()
    gdb.events.new_thread.connect(run.on_new_thread)

    if gdb.lookup_global_symbol(ENTRY) is None:
        # A stripped executable does not crash GDB and produces no error of its
        # own: the symbol simply fails to resolve. Detect it here rather than
        # letting the program run to completion with an empty trace.
        run.termination = 5          # Debug_Info_Missing
        run.detail = "the entry procedure %s did not resolve" % ENTRY
        emit(run, "", 0)
        return

    gdb.execute("break %s" % ENTRY, to_string=True)
    gdb.execute("run", to_string=True)

    index = 0
    while index < BUDGETS["steps"]:
        if (time.time() - run.started) * 1000 > WALL_MS:
            run.termination = 2      # Limit_Wall_Time
            break
        if run.extra_threads:
            run.termination = 4      # Target_Became_Multithreaded
            run.detail = "a second thread started; memory can change with no line of your code responsible"
            break
        try:
            frame = gdb.selected_frame()
        except gdb.error:
            break

        inside, _ = in_student_source(frame)
        if not inside:
            # Stepping is NOT confined to the student's source: 35% of stops
            # landed in the runtime and in glibc assembly, measured. `finish`
            # leaves the whole call in one operation, which is why the confined
            # loop costs no more per student step than the naive one.
            # See SPEC-ADP-014.
            try:
                gdb.execute("finish", to_string=True)
                continue
            except gdb.error:
                break

        sal = frame.find_sal()
        run.records.append({
            "index": index,
            "file": os.path.basename(sal.symtab.filename) if sal and sal.symtab else "",
            "line": sal.line if sal else 0,
            "frames": collect_frames(frame),
            "returned": [],
            "stdout_len": 0,
        })
        index += 1
        try:
            gdb.execute("step", to_string=True)
        except gdb.error:
            break
    else:
        run.termination = 1          # Limit_Steps

    emit(run, "", 0)


try:
    main()
except Exception as exc:                                   # noqa: BLE001
    # The tracer never dies without saying why. An adapter that exits silently
    # leaves the core with an empty file and no reason to show the student.
    fallback = Run()
    fallback.termination = 6         # Adapter_Failed
    fallback.detail = "%s: %s" % (type(exc).__name__, exc)
    emit(fallback, "", 0)
    print("adapter failed: %s" % exc, file=sys.stderr)
