"""The probe suite. SPEC-TEST-041.

This runs inside gdb's Python interpreter, one group per gdb invocation,
selected by the PROBE environment variable. It answers "does this toolchain
work?", separately from "is this code correct?" — which is what check.sh is for.

It is measurement, not product code (ROADMAP Phase 0), so it is Python rather
than Odin and it is allowed to be blunt. It is not throwaway: a row in the
compatibility table is only as good as the run that can be repeated.

Each group prints one line:

    PROBE_RESULT {"probe-name": {"ok": bool, "detail": str}, ...}

run.sh collects those lines and report.py turns them into the Markdown report.

THE TRAPS THIS FILE ENCODES, all of which cost time on 2026-08-05:

  * The entry symbol is `main::main`, with a double colon. `main.main` does not
    resolve.
  * A FinishBreakpoint whose stop() returns True, on a recursive procedure that
    also carries an ordinary breakpoint, never fires as expected: the deeper
    call's breakpoint interleaves first. The first reading of that was "return
    values are not observable". They are. Return False.
  * Counting threads at each stop detects nothing. A thread can be created and
    exit between two stops. Only gdb.events.new_thread catches it, and thread
    number 1 is the main thread.
  * Stepping is NOT confined to the student's source. 35% of stops landed in the
    runtime or in glibc. The mitigation is to `finish` out of any frame whose
    source file is not the student's (SPEC-ADP-014).
"""

import json
import os
import time

import gdb

SOURCE = os.environ.get("PROBE_SOURCE", "")
SOURCE_NAME = os.path.basename(SOURCE)
PROBE = os.environ.get("PROBE", "")

results = {}


def rec(name, ok, detail):
	results[name] = {"ok": bool(ok), "detail": str(detail)}


def quiet():
	gdb.execute("set confirm off")
	gdb.execute("set pagination off")


def break_line(marker):
	"""Find a line by marker rather than by number.

	A line number in this file goes stale the moment the target is edited, and
	a stale breakpoint makes a probe report a failure that is not one.
	"""
	with open(SOURCE, encoding="utf-8") as handle:
		for number, text in enumerate(handle, start=1):
			if marker in text:
				return number + 1  # the marker sits on the comment above
	raise RuntimeError("marker %r not found in %s" % (marker, SOURCE))


def current_file():
	"""The source file of the innermost frame, or "" if there is none."""
	try:
		sal = gdb.selected_frame().find_sal()
	except gdb.error:
		return ""
	if sal is None or sal.symtab is None:
		return ""
	return sal.symtab.filename


def current_line():
	try:
		sal = gdb.selected_frame().find_sal()
	except gdb.error:
		return None
	return sal.line if sal else None


def in_student_code():
	return current_file().endswith(SOURCE_NAME)


def read_elements(value, length, limit=32):
	"""Read a slice's elements through {data, len}, bounded."""
	count = min(length, limit)
	if count <= 0:
		return []
	element = value["data"].type.target()
	array = value["data"].cast(element.array(count - 1).pointer()).dereference()
	return [int(array[i]) for i in range(count)]


# --- groups -----------------------------------------------------------------


def group_symbols():
	"""entry-symbol, thread-count, free-symbol, line-table, only-student-code."""
	symbol = gdb.lookup_global_symbol("main::main")
	rec(
		"entry-symbol",
		symbol is not None,
		"main::main resolves to %s" % symbol if symbol else "main::main does not resolve",
	)
	if symbol is None:
		return

	gdb.execute("break main::main", to_string=True)
	gdb.execute("run", to_string=True)

	threads = len(gdb.selected_inferior().threads())
	rec("thread-count", threads == 1, "%d thread(s) in a plain program" % threads)

	found = []
	for name in (
		"runtime::heap_free",
		"runtime::mem_free",
		"runtime::heap_allocator_proc",
		"free",
	):
		try:
			if gdb.lookup_global_symbol(name):
				found.append(name)
				continue
			gdb.execute("info address " + name, to_string=True)
			found.append(name)
		except gdb.error:
			pass
	rec(
		"free-symbol",
		bool(found),
		"breakpoint-able: %s" % (", ".join(found) if found else "none"),
	)

	# Unmitigated stepping: how much of it lands outside the student's source?
	lines = []
	outside = 0
	for _ in range(60):
		if in_student_code():
			line = current_line()
			if line is not None:
				lines.append(line)
		else:
			outside += 1
		try:
			gdb.execute("step", to_string=True)
		except gdb.error:
			break
	total = len(lines) + outside
	rec(
		"line-table",
		len(lines) > 3,
		"student lines visited, in order: %s" % lines[:14],
	)
	rec(
		"only-student-code",
		outside == 0,
		"%d of %d plain `step` stops landed outside %s (%.0f%%). "
		"A failure here is expected and is why SPEC-ADP-014 exists."
		% (outside, total, SOURCE_NAME, 100.0 * outside / max(1, total)),
	)


def group_confined():
	"""The SPEC-ADP-014 mitigation, and step-cost with it in place."""
	gdb.execute("break main::main", to_string=True)
	gdb.execute("run", to_string=True)

	steps = 0
	escapes = 0
	start = time.time()
	while steps < 400:
		if not current_file():
			break
		if not in_student_code():
			try:
				gdb.execute("finish", to_string=True)
				escapes += 1
				continue
			except gdb.error:
				break
		steps += 1
		try:
			gdb.execute("step", to_string=True)
		except gdb.error:
			break
	elapsed = time.time() - start

	per_step = elapsed / max(1, steps) * 1000.0
	rec(
		"confined-stepping",
		steps > 0,
		"%d student steps, %d escapes by `finish`" % (steps, escapes),
	)
	rec(
		"step-cost",
		steps > 0,
		"%.2f ms per student step over %d steps (%.2f s total)"
		% (per_step, steps, elapsed),
	)
	results["step-cost"]["ms_per_step"] = round(per_step, 2)
	results["step-cost"]["steps"] = steps


def group_values():
	"""struct-fields, slice-fields, string-value, map-entries."""
	gdb.execute("break %s:%d" % (SOURCE_NAME, break_line("PROBE-BREAK")), to_string=True)
	gdb.execute("run", to_string=True)
	frame = gdb.selected_frame()

	try:
		student = frame.read_var("student")
		fields = [f.name for f in student.type.strip_typedefs().fields()]
		age = int(student["age"])
		rec(
			"struct-fields",
			fields == ["name", "marks", "age"] and age == 20,
			"fields=%s age=%d" % (fields, age),
		)
	except Exception as error:  # noqa: BLE001 - a probe records, it does not raise
		rec("struct-fields", False, error)

	try:
		marks = frame.read_var("marks")
		sub = frame.read_var("sub")
		parent_data, parent_len = int(marks["data"]), int(marks["len"])
		sub_data, sub_len = int(sub["data"]), int(sub["len"])
		values = read_elements(marks, parent_len)
		rec(
			"slice-fields",
			parent_len == 3 and sub_len == 2 and values == [7, 8, 9] and sub_data > parent_data,
			"marks={len:%d values:%s} sub={len:%d} sub.data - marks.data = %d bytes "
			"(shared storage, detectable from the observation alone)"
			% (parent_len, values, sub_len, sub_data - parent_data),
		)
	except Exception as error:  # noqa: BLE001
		rec("slice-fields", False, error)

	try:
		name = frame.read_var("student")["name"]
		length = int(name["len"])
		text = bytes(int(name["data"][i]) for i in range(length)).decode()
		rec("string-value", text == "Ana", 'read as "%s" (len=%d)' % (text, length))
	except Exception as error:  # noqa: BLE001
		rec("string-value", False, error)

	# R-20. The question is not whether the map reads nicely. It is whether the
	# entries are reachable AT ALL. If they are not, the model owes the student
	# a count and `unknown`, and owes it honestly.
	try:
		table = frame.read_var("table")
		table_type = table.type.strip_typedefs()
		fields = [f.name for f in table_type.fields()]
		length = None
		try:
			length = int(table["len"])
		except Exception:  # noqa: BLE001
			pass
		rec(
			"map-entries",
			False,
			"type=%s exposes %s. len=%s. No entry access. R-20 stands: a map "
			"shows its count and marks its entries unknown."
			% (table_type, fields, length),
		)
	except Exception as error:  # noqa: BLE001
		rec("map-entries", False, "map not readable at all: %s" % error)


def group_frames():
	"""frame-key and finish-breakpoint, under recursion. R-04, R-05.

	Two passes, because they ask different questions.

	Pass one is what SPEC-TEST-041 actually specifies for `frame-key`: the
	caller's (pc, sp) is readable at depth >= 2 and is STABLE within one
	invocation. A key that changes mid-invocation splits one frame into two in
	the picture. Counting distinct keys does not test this — a run can produce
	many distinct keys and still have every one of them unstable.

	Pass two attributes return values across every invocation.
	"""
	# --- pass one: readable at depth, and stable across a step ---------------
	gdb.execute("break main::fib", to_string=True)
	gdb.execute("run", to_string=True)
	for _ in range(4):  # descend a few levels before looking
		gdb.execute("continue", to_string=True)

	try:
		frame = gdb.selected_frame()
		depth = 0
		walker = frame
		while walker and depth < 12:
			walker = walker.older()
			depth += 1

		older = frame.older()
		before = (older.pc(), int(older.read_register("sp")))

		# Breakpoints stay live during `next`. If the stepped line contains a
		# recursive call, gdb stops inside the deeper invocation and the second
		# reading describes a different frame — which would look like
		# instability that is not there.
		gdb.execute("disable", to_string=True)
		gdb.execute("next", to_string=True)
		older_after = gdb.selected_frame().older()
		after = (older_after.pc(), int(older_after.read_register("sp")))

		rec(
			"frame-key",
			before == after and depth >= 2,
			"depth %d, caller key (pc, sp) = (%s, %s), unchanged after a step "
			"within the invocation: %s"
			% (depth, hex(before[0]), hex(before[1]), before == after),
		)
	except Exception as error:  # noqa: BLE001
		rec("frame-key", False, error)

	gdb.execute("delete", to_string=True)

	# --- pass two: attribution over every invocation -------------------------
	expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
	invocations = []
	returns = []

	class Finish(gdb.FinishBreakpoint):
		def __init__(self, frame, key, argument):
			super().__init__(frame, internal=True)
			self.key = key
			self.argument = argument

		def stop(self):
			try:
				value = int(self.return_value)
			except Exception:  # noqa: BLE001
				value = None
			returns.append((self.key, self.argument, value))
			return False  # THE TRAP. True here and the deeper call interleaves.

		def out_of_scope(self):
			returns.append((self.key, self.argument, "out-of-scope"))

	class Enter(gdb.Breakpoint):
		def stop(self):
			frame = gdb.selected_frame()
			try:
				argument = int(frame.read_var("n"))
			except Exception:  # noqa: BLE001
				argument = None
			older = frame.older()
			key = (
				(hex(older.pc()), hex(int(older.read_register("sp"))))
				if older
				else None
			)
			invocations.append((key, argument))
			try:
				Finish(frame, key, argument)
			except Exception:  # noqa: BLE001
				pass
			return False

	Enter("main::fib")
	gdb.execute("run", to_string=True)

	observed = [(k, n, v) for (k, n, v) in returns if isinstance(v, int)]
	wrong = [
		(k, n, v)
		for (k, n, v) in observed
		if not (0 <= n < len(expected)) or v != expected[n]
	]
	keys = set(key for key, _ in invocations)
	call_sites = {}
	for key, _ in invocations:
		if key:
			call_sites.setdefault(key[0], set()).add(key[1])

	rec(
		"frame-key-spread",
		len(invocations) > 10 and len(call_sites) > 1,
		"%d invocations produced %d distinct (caller pc, sp) keys across %d call "
		"sites. Fewer keys than invocations is correct: a key must be unique "
		"among frames that are live AT THE SAME TIME, and a returned frame's "
		"stack slot is reused by the next call from the same site."
		% (len(invocations), len(keys), len(call_sites)),
	)
	rec(
		"finish-breakpoint",
		len(observed) > 0 and len(wrong) == 0,
		"%d return values observed of %d invocations, %d wrong, %d out of scope. "
		"Sample (n, return): %s"
		% (
			len(observed),
			len(invocations),
			len(wrong),
			sum(1 for _, _, v in returns if v == "out-of-scope"),
			[(n, v) for _, n, v in observed[:10]],
		),
	)
	results["finish-breakpoint"]["wrong_returns"] = len(wrong)
	results["finish-breakpoint"]["invocations"] = len(invocations)


def group_simple_return():
	"""The other half of the pair: a return value on a NON-recursive procedure.

	Without this, "no wrong return value" passes by observing none at all.
	SPEC-TEST-022.
	"""
	seen = []

	class Finish(gdb.FinishBreakpoint):
		def __init__(self, frame):
			super().__init__(frame, internal=True)

		def stop(self):
			try:
				seen.append(int(self.return_value))
			except Exception:  # noqa: BLE001
				seen.append(None)
			return False

	class Enter(gdb.Breakpoint):
		def stop(self):
			try:
				Finish(gdb.selected_frame())
			except Exception:  # noqa: BLE001
				pass
			return False

	Enter("main::double")
	gdb.execute("run", to_string=True)
	rec(
		"simple-return",
		seen == [42],
		"double(21) observed as %s (expected [42])" % seen,
	)


def group_threads():
	"""thread-event. The count-based version of this detects nothing."""
	extra = []

	def on_new_thread(event):
		thread = event.inferior_thread
		if thread.num != 1:  # 1 is the main thread
			extra.append(thread.num)

	gdb.events.new_thread.connect(on_new_thread)

	gdb.execute("break main::main", to_string=True)
	gdb.execute("run", to_string=True)

	max_counted = 0
	steps = 0
	stopped_at = None
	for _ in range(300):
		if not current_file():
			break
		if not in_student_code():
			try:
				gdb.execute("finish", to_string=True)
				continue
			except gdb.error:
				break
		max_counted = max(max_counted, len(gdb.selected_inferior().threads()))
		if extra:
			stopped_at = current_line()
			break
		steps += 1
		try:
			gdb.execute("step", to_string=True)
		except gdb.error:
			break

	rec(
		"thread-event",
		bool(extra),
		"extra threads seen by event: %s, after %d steps, at line %s"
		% (extra, steps, stopped_at),
	)
	rec(
		"thread-count-is-unsound",
		max_counted <= 1,
		"the per-stop thread count never rose above %d, while the event caught "
		"%d. A safeguard built on the count would never fire, which is worse "
		"than none — its presence implies protection."
		% (max_counted, len(extra)),
	)


def group_no_debug_info():
	"""A stripped executable must be detected, not crashed on."""
	symbol = gdb.lookup_global_symbol("main::main")
	rec(
		"no-debug-info",
		symbol is None,
		"lookup_global_symbol('main::main') on a stripped build returned %s. "
		"That is the DEBUG_INFO_MISSING check: gdb itself does not fail, so the "
		"adapter must detect this and name the error." % symbol,
	)


GROUPS = {
	"symbols": group_symbols,
	"confined": group_confined,
	"values": group_values,
	"frames": group_frames,
	"simple-return": group_simple_return,
	"threads": group_threads,
	"no-debug-info": group_no_debug_info,
}


quiet()
try:
	GROUPS[PROBE]()
except Exception as error:  # noqa: BLE001
	rec(PROBE + "-group", False, "the group itself failed: %r" % (error,))
print("PROBE_RESULT " + json.dumps(results))
