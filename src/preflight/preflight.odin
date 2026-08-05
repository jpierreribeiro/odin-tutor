// Package tutor_preflight checks the environment before anything is compiled.
//
// It exists so that a missing tool produces a named error and an instruction,
// rather than a failure deeper in the run whose message is the debugger's.
// See REQ-GEN-003, REQ-ERR-001.
package tutor_preflight

import "core:fmt"
import "core:os"
import "core:strings"

// Failure names every way preflight can refuse to continue. An enum, because
// none of these carries data the caller acts on beyond the name.
// See docs/decisions/ADR-013.
Failure :: enum {
	None,
	Odin_Missing,
	Debugger_Missing,
	Debugger_Without_Python,
	Toolchain_Unsupported,
}

// Report is what preflight learned. It is recorded in the run report even when
// nothing failed, so that a bug report carries the versions that produced it.
Report :: struct {
	odin_version:     string,
	debugger_version: string,
	debugger_python:  bool,
	// listed says whether this combination has a row in the compatibility
	// matrix. An unlisted combination warns and continues; it does not refuse.
	// Refusing would make the tool unusable the day a new Odin is released.
	// See ADR-009.
	listed:           bool,
	failure:          Failure,
}

// Known is one row of the compatibility matrix. A row exists only when the
// probe suite passed on that combination and its report was committed.
// See SPEC-PLAT-031.
Known :: struct {
	odin_prefix:     string,
	debugger_prefix: string,
	good:            bool,
}

// KNOWN_TOOLCHAINS is the matrix. One row, from the run committed under
// fixtures/toolchain/. It is deliberately short: a combination the project
// cannot prove does not belong here.
KNOWN_TOOLCHAINS :: []Known {
	{odin_prefix = "dev-2026-08", debugger_prefix = "GNU gdb (Ubuntu 15.1", good = true},
}

// explain turns a failure into a sentence a student can act on.
//
// Every branch names the tool and says what to do. An error that only names
// itself makes the student search instead of fix. See REQ-ERR-002.
explain :: proc(f: Failure, allocator := context.allocator) -> string {
	switch f {
	case .None:
		return strings.clone("", allocator)
	case .Odin_Missing:
		return strings.clone(
			"TOOLCHAIN_MISSING: the Odin compiler was not found on PATH. Install Odin, or add it to PATH.",
			allocator,
		)
	case .Debugger_Missing:
		return strings.clone(
			"TOOLCHAIN_MISSING: gdb was not found on PATH. On Debian or Ubuntu: apt install gdb.",
			allocator,
		)
	case .Debugger_Without_Python:
		return strings.clone(
			"DEBUGGER_WITHOUT_PYTHON: this gdb was built without Python, and the tracer runs inside it. " +
			"Install a gdb built with Python support; `gdb --configuration` lists it.",
			allocator,
		)
	case .Toolchain_Unsupported:
		return strings.clone(
			"TOOLCHAIN_UNSUPPORTED: this combination is recorded as producing an incorrect picture. " +
			"See docs/PLATFORM-SUPPORT.md.",
			allocator,
		)
	}
	return strings.clone("Unknown failure.", allocator)
}

// classify decides what to do with a pair of versions.
//
// Three outcomes, and the third is the one that matters: an unlisted
// combination warns and continues. See ADR-009.
classify :: proc(odin_version, debugger_version: string) -> (listed: bool, failure: Failure) {
	for row in KNOWN_TOOLCHAINS {
		if strings.has_prefix(odin_version, row.odin_prefix) &&
		   strings.has_prefix(debugger_version, row.debugger_prefix) {
			if !row.good {
				return true, .Toolchain_Unsupported
			}
			return true, .None
		}
	}
	return false, .None
}

// has_python reads the debugger's own configuration output.
has_python :: proc(configuration: string) -> bool {
	return strings.contains(configuration, "--with-python")
}

// warning is what an unlisted combination prints. It is a warning and not a
// refusal, and it names both versions so a bug report carries them.
warning :: proc(r: Report, allocator := context.allocator) -> string {
	if r.listed {
		return strings.clone("", allocator)
	}
	return fmt.aprintf(
		"This combination is not in the compatibility matrix: Odin %s with %s. " +
		"Continuing. If the picture looks wrong, that is the first thing to report.",
		r.odin_version, r.debugger_version, allocator = allocator,
	)
}

// find_tool reports whether a program exists on PATH.
find_tool :: proc(name: string) -> bool {
	path := os.get_env("PATH", context.temp_allocator)
	for dir in strings.split(path, ":", context.temp_allocator) {
		if dir == "" {
			continue
		}
		candidate := strings.concatenate({dir, "/", name}, context.temp_allocator)
		if os.exists(candidate) {
			return true
		}
	}
	return false
}
