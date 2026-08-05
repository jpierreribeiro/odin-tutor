// Package tutor_toolchain starts the external processes: the compiler and the
// debugger.
//
// ARCHITECTURE.md §2 lists Build and Adapter as separate components. They are
// one package here because both do the same small thing — start a program,
// capture its output, name what went wrong — and splitting them would produce
// two packages with one caller each. That is structure without a reason
// (ADR-013, AGENT-GUIDE Rule 7). The responsibilities stay separate: `build`
// never reads target memory, and `trace` never chooses a build flag.
//
// Nothing here reaches the network (REQ-GEN-001, SPEC-SAFE-060). The only
// processes started are `odin` and `gdb`, both named literally.
package tutor_toolchain

import "core:fmt"
import "core:hash"
import "core:os"
import "core:strings"

// Failure names every way this package can refuse to continue.
//
// An enum: none of these carries data the caller acts on beyond the name, and
// the diagnostics travel in the result struct rather than in the error
// (ADR-013 §1).
Failure :: enum {
	None,
	Odin_Missing,
	Debugger_Missing,
	Source_Unreadable,
	Cache_Unwritable,
	Compile_Failed,
	Adapter_Missing,
	Adapter_Failed,
	Observations_Missing,
}

// Versions is what the two external tools report about themselves.
//
// It is carried rather than re-read, because the build cache key depends on it
// and a key that re-reads its own inputs can disagree with itself mid-run.
Versions :: struct {
	odin:                   string,
	debugger:               string,
	debugger_configuration: string,
}

// Build_Result says what happened, including whether the compiler ran at all.
Build_Result :: struct {
	executable:  string,
	cached:      bool,
	diagnostics: string,
}

// explain turns a failure into a sentence a student can act on.
//
// Every branch names the tool and says what to do. See REQ-ERR-002.
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
	case .Source_Unreadable:
		return strings.clone(
			"SOURCE_UNREADABLE: the .odin file could not be read. Check the path.",
			allocator,
		)
	case .Cache_Unwritable:
		return strings.clone(
			"CACHE_UNWRITABLE: the build cache directory could not be created. " +
			"Set XDG_CACHE_HOME to a writable directory.",
			allocator,
		)
	case .Compile_Failed:
		return strings.clone(
			"COMPILE_FAILED: the program did not compile. The compiler's own message is above, " +
			"unchanged — it names the line, and it is the thing to fix first.",
			allocator,
		)
	case .Adapter_Missing:
		return strings.clone(
			"ADAPTER_MISSING: adapter/gdb_extractor.py was not found. It runs inside gdb and does the reading.",
			allocator,
		)
	case .Adapter_Failed:
		return strings.clone(
			"ADAPTER_FAILED: the debugger ran but the adapter produced nothing. " +
			"Check that this gdb has Python: `gdb --configuration`.",
			allocator,
		)
	case .Observations_Missing:
		return strings.clone(
			"OBSERVATIONS_MISSING: the adapter finished without writing an observation stream.",
			allocator,
		)
	}
	return strings.clone("Unknown failure.", allocator)
}

// capture runs a program and returns what it wrote, with the exit code.
//
// It is the only place a process is started, so the "no network, no shell"
// property is checkable by reading one procedure. There is no shell: the
// command is a list of arguments, never a string a shell would re-parse
// (SPEC-SAFE-041).
capture :: proc(
	command: []string,
	allocator := context.allocator,
) -> (
	stdout: string,
	stderr: string,
	exit_code: int,
	ok: bool,
) {
	state, out_bytes, err_bytes, run_err := os.process_exec(
		os.Process_Desc{command = command},
		allocator,
	)
	if run_err != nil {
		delete(out_bytes, allocator)
		delete(err_bytes, allocator)
		return "", "", 0, false
	}
	return string(out_bytes), string(err_bytes), state.exit_code, true
}

// detect asks both tools what they are.
//
// The versions are not decoration. SPEC-PLAT-030 compares them against the
// compatibility matrix, and the build cache key includes the Odin version
// because a cached executable from another compiler is not the same executable.
detect :: proc(allocator := context.allocator) -> (versions: Versions, failure: Failure) {
	odin_out, _, _, odin_ok := capture([]string{"odin", "version"}, allocator)
	if !odin_ok {
		return {}, .Odin_Missing
	}
	versions.odin = strings.clone(strings.trim_space(strings.trim_prefix(
		strings.trim_space(odin_out), "odin version ")), allocator)
	delete(odin_out, allocator)

	gdb_out, _, _, gdb_ok := capture([]string{"gdb", "--version"}, allocator)
	if !gdb_ok {
		return versions, .Debugger_Missing
	}
	versions.debugger = strings.clone(first_line(gdb_out), allocator)
	delete(gdb_out, allocator)

	// `gdb --configuration` is how the Python question is answered. A gdb
	// without Python runs the extractor not at all, and the failure it produces
	// on its own does not say why.
	configuration_out, _, _, configuration_ok := capture(
		[]string{"gdb", "--configuration"}, allocator,
	)
	if configuration_ok {
		versions.debugger_configuration = strings.clone(configuration_out, allocator)
		delete(configuration_out, allocator)
	}
	return versions, .None
}

first_line :: proc(text: string) -> string {
	for r, i in text {
		if r == '\n' {
			return text[:i]
		}
	}
	return text
}

// cache_root is where built executables live.
//
// Not beside the student's source. A full run must leave every student-authored
// file byte-identical (ROADMAP Phase 1, acceptance 6), and the surest way to
// keep that true is to write nothing into their directory at all.
cache_root :: proc(allocator := context.allocator) -> string {
	if xdg := os.get_env("XDG_CACHE_HOME", context.temp_allocator); xdg != "" {
		return strings.concatenate({xdg, "/odin-tutor"}, allocator)
	}
	home := os.get_env("HOME", context.temp_allocator)
	return strings.concatenate({home, "/.cache/odin-tutor"}, allocator)
}

// cache_key identifies a built executable.
//
// THE TRAP this key exists to avoid: caching across a toolchain change. The
// trace's correctness depends on the debug information a specific compiler
// version emits, so an executable built by another Odin is a different
// executable even when the source is byte-identical. Reusing it would produce a
// picture from one toolchain while the tool reports another
// (SPEC-PLAT-030, AGENT-GUIDE §6).
//
// FNV-1a over the source bytes and the version string. Not a security hash:
// nothing here defends against a chosen collision, and saying so is cheaper
// than the next reader wondering.
cache_key :: proc(source_bytes: []byte, odin_version: string, allocator := context.allocator) -> string {
	digest := hash.fnv64a(source_bytes)
	digest = hash.fnv64a(transmute([]byte)odin_version, digest)
	return fmt.aprintf("%016x", digest, allocator = allocator)
}

// build compiles the target with debug information, and skips the compiler when
// an executable for this exact source and toolchain already exists.
//
// Compilation dominates: measured at 0.98 s against 0.4 s to generate a
// 300-step trace. A student who edits, runs, edits, runs pays that second every
// time, and the cache is what keeps the loop usable (SPEC-PERF-012).
build :: proc(
	source_path: string,
	versions: Versions,
	allocator := context.allocator,
) -> (
	result: Build_Result,
	failure: Failure,
) {
	source_bytes, read_ok := os.read_entire_file(source_path, context.temp_allocator)
	if !read_ok {
		return {}, .Source_Unreadable
	}

	root := cache_root(context.temp_allocator)
	if os.make_directory_all(root) != nil && !os.exists(root) {
		return {}, .Cache_Unwritable
	}

	key := cache_key(source_bytes, versions.odin, context.temp_allocator)
	result.executable = strings.concatenate({root, "/", key}, allocator)

	if os.exists(result.executable) {
		result.cached = true
		return result, .None
	}

	// -debug is not negotiable and does not come from the exercise. An exercise
	// is data; a build flag from an exercise is a way to run arbitrary compiler
	// behaviour (ARCHITECTURE.md §2, SPEC-EX-001).
	out_flag := strings.concatenate({"-out:", result.executable}, context.temp_allocator)
	stdout_text, stderr_text, exit_code, ok := capture(
		[]string{"odin", "build", source_path, "-file", "-debug", out_flag},
		allocator,
	)
	if !ok {
		return result, .Odin_Missing
	}

	// The compiler's own message is passed through unchanged. Rewriting it
	// would drop the line number, which is the part the student needs.
	result.diagnostics = strings.concatenate({stdout_text, stderr_text}, allocator)
	delete(stdout_text, allocator)
	delete(stderr_text, allocator)

	if exit_code != 0 || !os.exists(result.executable) {
		return result, .Compile_Failed
	}
	return result, .None
}

// Trace_Request is everything the adapter needs.
//
// Configuration reaches the adapter through the environment, never through
// argv, so no path from an exercise reaches a command line (SPEC-SAFE-042).
Trace_Request :: struct {
	executable:        string,
	source_path:       string,
	observations_path: string,
	adapter_path:      string,
	versions:          Versions,
}

// trace runs the target once, under the debugger, and leaves an observation
// stream on disk.
//
// The stream is a file rather than a pipe on purpose. It is what makes every
// later phase testable in milliseconds with the debugger absent, and it is the
// thing ROADMAP Phase 1 acceptance 3 asks for: replaying it must produce an
// identical trace.
trace :: proc(request: Trace_Request, allocator := context.allocator) -> (diagnostics: string, failure: Failure) {
	if !os.exists(request.adapter_path) {
		return "", .Adapter_Missing
	}

	// -nx: the debugger must not be scriptable from the working directory, or a
	// file dropped beside an exercise runs inside it (SPEC-SAFE-040).
	command := []string{
		"gdb", "-q", "-nx", "--batch",
		"-x", request.adapter_path,
		request.executable,
	}

	environment := []string{
		strings.concatenate({"TUTOR_SOURCE=", request.source_path}, context.temp_allocator),
		strings.concatenate({"TUTOR_OUT=", request.observations_path}, context.temp_allocator),
		strings.concatenate({"TUTOR_ODIN_VERSION=", request.versions.odin}, context.temp_allocator),
		strings.concatenate({"PATH=", os.get_env("PATH", context.temp_allocator)}, context.temp_allocator),
		strings.concatenate({"HOME=", os.get_env("HOME", context.temp_allocator)}, context.temp_allocator),
	}

	state, out_bytes, err_bytes, run_err := os.process_exec(
		os.Process_Desc{command = command, env = environment},
		allocator,
	)
	diagnostics = strings.concatenate({string(out_bytes), string(err_bytes)}, allocator)
	delete(out_bytes, allocator)
	delete(err_bytes, allocator)

	if run_err != nil {
		return diagnostics, .Debugger_Missing
	}
	if !os.exists(request.observations_path) {
		// gdb exits 0 having done nothing when its Python is missing, so the
		// exit code alone does not answer this. The file does.
		return diagnostics, .Observations_Missing
	}
	_ = state
	return diagnostics, .None
}
