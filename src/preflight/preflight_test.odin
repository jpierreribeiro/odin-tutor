package tutor_preflight

import "core:strings"
import "core:testing"

@(test)
a_gdb_without_python_is_detected :: proc(t: ^testing.T) {
	// The whole extractor design runs inside the debugger's Python. A gdb
	// without it must fail at preflight, before anything is compiled.
	with := "This GDB was configured as follows:\n --with-python=/usr (relocatable)\n"
	without := "This GDB was configured as follows:\n --without-python\n"
	testing.expect(t, has_python(with), "a gdb with Python is recognised")
	testing.expect(t, !has_python(without), "a gdb without Python is caught")
}

@(test)
a_listed_combination_continues :: proc(t: ^testing.T) {
	listed, failure := classify("dev-2026-08:9caff63", "GNU gdb (Ubuntu 15.1-1ubuntu1~24.04.1) 15.1")
	testing.expect(t, listed, "the committed row must match itself")
	testing.expect_value(t, failure, Failure.None)
}

@(test)
an_unlisted_combination_warns_and_continues :: proc(t: ^testing.T) {
	// The row that matters. Refusing an unlisted version would make the tool
	// unusable the day a new Odin ships; continuing silently would let it lie.
	// See ADR-009.
	listed, failure := classify("dev-2099-01:ffffff", "GNU gdb 42.0")
	testing.expect(t, !listed, "an unknown combination is not listed")
	testing.expect_value(t, failure, Failure.None)

	r := Report{odin_version = "dev-2099-01", debugger_version = "GNU gdb 42.0", listed = false}
	msg := warning(r, context.temp_allocator)
	testing.expect(t, strings.contains(msg, "dev-2099-01"), "the warning names the Odin version")
	testing.expect(t, strings.contains(msg, "42.0"), "and the debugger version")
}

@(test)
every_failure_explains_what_to_do :: proc(t: ^testing.T) {
	// REQ-ERR-002: every error is named, and the name is not the whole message.
	for f in Failure {
		if f == .None {
			continue
		}
		msg := explain(f, context.temp_allocator)
		testing.expect(t, len(msg) > 30, "a failure needs a sentence, not a label")
		testing.expect(t, strings.contains(msg, ":"), "a named error carries its identifier")
	}
}
