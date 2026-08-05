// Package tutor_cli is the entry point.
//
// It wires the pieces together and owns no logic of its own. Anything that
// decides what the picture says lives in tutor_model, where it is tested
// without a debugger.
package tutor_cli

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:time"
import "core:path/filepath"
import "core:strings"
import tutor_model "../model"
import tutor_obs "../obs"
import tutor_preflight "../preflight"
import tutor_render "../render"
import tutor_toolchain "../toolchain"
import tutor_tui "../tui"

USAGE :: `odin-tutor — see what your Odin program does to memory

  odin-tutor preflight
      Check the toolchain and report what was found.

  odin-tutor trace <program.odin> <trace.json>
      Compile the program, run it once under the debugger, and write the trace.
      The observation stream is written beside it, as <trace.json>.observations,
      so the same trace can be rebuilt with `+"`assemble`"+` and no debugger at all.

  odin-tutor assemble <observations.json> <trace.json>
      Turn an adapter's observation stream into a trace.

  odin-tutor play <trace.json> [--ascii] [--no-colour]
      Step through the trace. Arrow keys move, g jumps, q quits.
      Nothing is re-run: the trace is read, never the program.

  odin-tutor render <trace.json> [step] [--unicode]
      Print one step. Step numbers start at 1. Default is 1.
      The same information as the interactive screen, as plain text.
      --unicode uses the same glyphs the screen does, and loses nothing
      without it.

  odin-tutor bench <trace.json>
      Measure navigation: how long materialising each step takes.
      SPEC-PERF-010 requires under 16 ms at the 99th percentile.

  odin-tutor version

Nothing here reaches the network. Nothing is written outside the paths you name,
except built executables, which are cached under $XDG_CACHE_HOME/odin-tutor so
that your own directory is left exactly as you left it.`

main :: proc() {
	args := os.args[1:]
	if len(args) == 0 {
		fmt.println(USAGE)
		os.exit(2)
	}

	switch args[0] {
	case "preflight":
		os.exit(cmd_preflight())
	case "trace":
		if len(args) != 3 {
			fmt.eprintln("trace needs a .odin file and an output path")
			os.exit(2)
		}
		os.exit(cmd_trace(args[1], args[2]))
	case "assemble":
		if len(args) != 3 {
			fmt.eprintln("assemble needs an input and an output path")
			os.exit(2)
		}
		os.exit(cmd_assemble(args[1], args[2]))
	case "play":
		if len(args) < 2 {
			fmt.eprintln("play needs a trace path")
			os.exit(2)
		}
		style := tutor_render.FANCY
		for flag in args[2:] {
			switch flag {
			case "--ascii":
				style.unicode = false
			case "--no-colour", "--no-color":
				style.colour = false
			case:
				fmt.eprintfln("unknown option: %s", flag)
				os.exit(2)
			}
		}
		os.exit(cmd_play(args[1], style))
	case "render":
		if len(args) < 2 {
			fmt.eprintln("render needs a trace path")
			os.exit(2)
		}
		index := 1
		// PLAIN by default: a golden is read by a test and pasted into a bug
		// report, and both want no escape sequences (SPEC-TUI-050).
		style := tutor_render.PLAIN
		for argument in args[2:] {
			if argument == "--unicode" {
				style.unicode = true
				continue
			}
			parsed, parse_ok := strconv.parse_int(argument)
			if !parse_ok || parsed < 1 {
				fmt.eprintln("BAD_STEP: the step must be a positive whole number.")
				os.exit(2)
			}
			index = parsed
		}
		os.exit(cmd_render(args[1], index, style))
	case "bench":
		if len(args) != 2 {
			fmt.eprintln("bench needs a trace path")
			os.exit(2)
		}
		os.exit(cmd_bench(args[1]))
	case "version":
		fmt.printfln("odin-tutor (planning skeleton), trace format v%d, observation format v%d",
			tutor_model.TRACE_VERSION, tutor_obs.SCHEMA_VERSION)
		os.exit(0)
	case:
		fmt.eprintfln("unknown command: %s", args[0])
		fmt.println(USAGE)
		os.exit(2)
	}
}

// examine runs the whole of preflight and reports what it found.
//
// It is shared by the `preflight` command and by `trace`, because a trace
// produced on an unchecked toolchain is exactly the case SPEC-PLAT-030 exists to
// prevent: the tool's correctness depends on the debug information a specific
// compiler emits, and that is not a constant.
examine :: proc(allocator := context.allocator) -> (tutor_preflight.Report, tutor_toolchain.Versions) {
	report: tutor_preflight.Report

	if !tutor_preflight.find_tool("odin") {
		report.failure = .Odin_Missing
		return report, {}
	}
	if !tutor_preflight.find_tool("gdb") {
		report.failure = .Debugger_Missing
		return report, {}
	}

	versions, detect_failure := tutor_toolchain.detect(allocator)
	if detect_failure != .None {
		report.failure = detect_failure == .Odin_Missing ? .Odin_Missing : .Debugger_Missing
		return report, versions
	}

	report.odin_version = versions.odin
	report.debugger_version = versions.debugger
	report.debugger_python = tutor_preflight.has_python(versions.debugger_configuration)
	if !report.debugger_python {
		report.failure = .Debugger_Without_Python
		return report, versions
	}

	report.listed, report.failure = tutor_preflight.classify(versions.odin, versions.debugger)
	return report, versions
}

cmd_preflight :: proc() -> int {
	report, _ := examine(context.temp_allocator)

	if report.failure != .None {
		fmt.eprintln(tutor_preflight.explain(report.failure, context.temp_allocator))
		return 1
	}

	fmt.printfln("odin   %s", report.odin_version)
	fmt.printfln("gdb    %s", report.debugger_version)
	fmt.println("       built with Python, which the tracer runs inside")
	fmt.println()
	if report.listed {
		fmt.println("This combination is in the compatibility matrix, backed by a committed probe run.")
	} else {
		fmt.println(tutor_preflight.warning(report, context.temp_allocator))
	}
	return 0
}

cmd_trace :: proc(source_path, trace_path: string) -> int {
	report, versions := examine(context.temp_allocator)
	if report.failure != .None {
		fmt.eprintln(tutor_preflight.explain(report.failure, context.temp_allocator))
		return 1
	}
	if !report.listed {
		// A warning, not a refusal. Refusing would make the tool unusable the
		// day a new Odin is released, and the student would have no way to tell
		// a real defect from an untested version. See ADR-009.
		fmt.eprintln(tutor_preflight.warning(report, context.temp_allocator))
	}

	built, build_failure := tutor_toolchain.build(source_path, versions, context.temp_allocator)
	if build_failure != .None {
		if built.diagnostics != "" {
			fmt.eprint(built.diagnostics)
		}
		fmt.eprintln(tutor_toolchain.explain(build_failure, context.temp_allocator))
		return 1
	}
	fmt.printfln("%s  %s", built.cached ? "cached" : "built ", source_path)

	observations_path := strings.concatenate(
		{trace_path, ".observations"}, context.temp_allocator,
	)
	adapter_path := adapter_location(context.temp_allocator)

	diagnostics, trace_failure := tutor_toolchain.trace(
		tutor_toolchain.Trace_Request{
			executable        = built.executable,
			source_path       = source_path,
			observations_path = observations_path,
			adapter_path      = adapter_path,
			versions          = versions,
		},
		context.temp_allocator,
	)
	if trace_failure != .None {
		if diagnostics != "" {
			fmt.eprint(diagnostics)
		}
		fmt.eprintln(tutor_toolchain.explain(trace_failure, context.temp_allocator))
		return 1
	}
	fmt.printfln("traced  %s", observations_path)

	// The trace is assembled from the file, not from anything held in memory
	// during the run. That is what makes the recorded stream a real replay: if
	// this path works, `assemble` on the same file works with gdb uninstalled
	// (ROADMAP Phase 1, acceptance 3).
	return cmd_assemble(observations_path, trace_path)
}

// adapter_location finds the extractor.
//
// TUTOR_ADAPTER so a test can point at a copy, otherwise the repository layout.
// Both are named paths. The adapter is NOT searched for in the working
// directory: an adapter found that way is an adapter an exercise could replace,
// and it runs inside the debugger (SPEC-SAFE-040).
//
// This is the version 1 answer and it assumes the tool runs from the repository
// root. An installed build needs a real install path, which is a packaging
// decision this project has not made.
adapter_location :: proc(allocator := context.allocator) -> string {
	if from_env := os.get_env("TUTOR_ADAPTER", context.temp_allocator); from_env != "" {
		return strings.clone(from_env, allocator)
	}
	return strings.clone("adapter/gdb_extractor.py", allocator)
}

cmd_assemble :: proc(input_path, output_path: string) -> int {
	data, read_err := os.read_entire_file(input_path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("INPUT_UNREADABLE: could not read %s", input_path)
		return 1
	}
	defer delete(data)

	stream, decode_err := tutor_obs.decode(data)
	if decode_err != .None {
		switch decode_err {
		case .None:
		case .Malformed_Json:
			fmt.eprintln("OBSERVATION_MALFORMED: the adapter's output is not valid JSON.")
		case .Unsupported_Version:
			fmt.eprintfln(
				"OBSERVATION_VERSION: this build reads observation format v%d, and the file is a different version.",
				tutor_obs.SCHEMA_VERSION,
			)
		}
		return 1
	}

	assembly: tutor_model.Assembly
	if tutor_model.assembly_init(&assembly) != nil {
		fmt.eprintln("OUT_OF_MEMORY: could not reserve the assembly arena.")
		return 1
	}
	defer tutor_model.assembly_destroy(&assembly)

	trace, build_err := tutor_model.assemble(&assembly, stream)
	if build_err == .Budget_Disagreement {
		// The core cannot verify a budget the adapter enforced at the read.
		// The declaration is the only check available, so a disagreement is
		// reported rather than absorbed. See ADR-006.
		fmt.eprintln(
			"BUDGET_DISAGREEMENT: the adapter reports different limits from the ones this build expects. " +
			"The trace was not written, because a picture drawn under unknown limits cannot be trusted.",
		)
		return 1
	}

	encoded, encode_ok := tutor_model.encode(trace, context.allocator)
	if !encode_ok {
		fmt.eprintln("TRACE_UNWRITABLE: the trace could not be encoded.")
		return 1
	}
	defer delete(encoded)

	if os.write_entire_file(output_path, encoded) != nil {
		fmt.eprintfln("OUTPUT_UNWRITABLE: could not write %s", output_path)
		return 1
	}

	fmt.printfln("%d steps written to %s", len(trace.steps), output_path)
	fmt.println(tutor_model.describe_termination(trace, context.temp_allocator))
	return 0
}

// source_beside finds the student's source next to the trace, for the CODE
// region.
//
// Missing source is not missing information about memory, so a trace whose
// program has moved still plays: the other three regions are drawn and the
// student is not stopped. See SPEC-TUI-043 for the same principle under width.
source_beside :: proc(trace: tutor_model.Trace, trace_path: string, allocator := context.allocator) -> []string {
	if trace.source_file == "" {
		return nil
	}
	// NOT deleted. `filepath.dir` returns a SLICE OF ITS INPUT — it calls
	// split_path and hands back a substring, allocating nothing. Freeing it
	// frees a pointer the caller owns, and when the caller is argv that is a
	// pointer into the stack. This segfaulted before it was read.
	directory := filepath.dir(trace_path)
	beside, join_err := filepath.join({directory, trace.source_file}, context.temp_allocator)
	if join_err != nil {
		beside = trace.source_file
	}
	for candidate in ([]string{beside, trace.source_file}) {
		data, err := os.read_entire_file(candidate, allocator)
		if err == nil {
			return strings.split_lines(string(data), allocator)
		}
	}
	return nil
}

cmd_play :: proc(trace_path: string, style: tutor_render.Style) -> int {
	data, read_err := os.read_entire_file(trace_path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("INPUT_UNREADABLE: could not read %s", trace_path)
		return 1
	}
	defer delete(data)

	trace, ok := tutor_model.decode(data)
	if !ok {
		fmt.eprintfln(
			"TRACE_VERSION: this build reads trace format v%d, and the file is a different version.",
			tutor_model.TRACE_VERSION,
		)
		return 1
	}
	source := source_beside(trace, trace_path, context.temp_allocator)
	return tutor_tui.run(trace, source, style)
}

// cmd_bench measures what navigation actually costs.
//
// SPEC-PERF-032: a performance claim is backed by a recorded number, not by an
// intuition. This exists so the 16 ms in SPEC-PERF-010 is checkable by anyone
// on their own machine and their own largest trace, rather than asserted here.
//
// It measures MATERIALISATION, which is the whole cost of moving to a step:
// applying at most K-1 deltas to a keyframe. Nothing is re-run, and that is the
// property being measured — a navigation that compiled or executed anything
// could not meet this budget at all.
cmd_bench :: proc(trace_path: string) -> int {
	data, read_err := os.read_entire_file(trace_path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("INPUT_UNREADABLE: could not read %s", trace_path)
		return 1
	}
	defer delete(data)

	trace, ok := tutor_model.decode(data)
	if !ok {
		fmt.eprintln("TRACE_VERSION: this build reads a different trace format.")
		return 1
	}
	if len(trace.steps) == 0 {
		fmt.eprintln("The trace has no steps.")
		return 1
	}

	samples := make([]f64, len(trace.steps), context.allocator)
	defer delete(samples)

	// Every step, in a shuffled-in-effect order: the worst case for a keyframe
	// scheme is a jump, not a walk, so measuring only sequential steps would
	// measure the easy case. Going backwards from the end does that without
	// needing randomness, which the trace format forbids anyway.
	for i in 0 ..< len(trace.steps) {
		index := len(trace.steps) - 1 - i
		started := time.now()
		entities, materialise_ok := tutor_model.materialise(trace, index, context.temp_allocator)
		elapsed := time.duration_milliseconds(time.since(started))
		if !materialise_ok {
			fmt.eprintfln("TRACE_CORRUPT: step %d could not be reconstructed.", index + 1)
			return 1
		}
		_ = entities
		samples[i] = elapsed
		free_all(context.temp_allocator)
	}

	slice.sort(samples)
	total := 0.0
	for s in samples {
		total += s
	}
	p99 := samples[min(len(samples) - 1, int(f64(len(samples)) * 0.99))]

	fmt.printfln("steps          %d", len(trace.steps))
	fmt.printfln("keyframe every %d", trace.keyframe_interval)
	fmt.printfln("min            %.4f ms", samples[0])
	fmt.printfln("mean           %.4f ms", total / f64(len(samples)))
	fmt.printfln("p99            %.4f ms", p99)
	fmt.printfln("max            %.4f ms", samples[len(samples) - 1])
	fmt.println()
	if p99 < 16.0 {
		fmt.printfln("SPEC-PERF-010 met: %.4f ms at the 99th percentile, under 16 ms.", p99)
		return 0
	}
	fmt.printfln("SPEC-PERF-010 NOT met: %.4f ms at the 99th percentile.", p99)
	return 1
}

cmd_render :: proc(trace_path: string, step_number: int, style := tutor_render.PLAIN) -> int {
	data, read_err := os.read_entire_file(trace_path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("INPUT_UNREADABLE: could not read %s", trace_path)
		return 1
	}
	defer delete(data)

	trace, ok := tutor_model.decode(data)
	if !ok {
		fmt.eprintfln(
			"TRACE_VERSION: this build reads trace format v%d, and the file is a different version.",
			tutor_model.TRACE_VERSION,
		)
		return 1
	}
	if len(trace.steps) == 0 {
		fmt.println("The trace has no steps.")
		fmt.println(tutor_model.describe_termination(trace, context.temp_allocator))
		return 0
	}

	index := step_number - 1
	if index < 0 || index >= len(trace.steps) {
		fmt.eprintfln("NO_SUCH_STEP: the trace has %d steps.", len(trace.steps))
		return 1
	}

	// Navigation reads the trace. It does not run the program, does not run
	// the compiler, and does not start a debugger. See SPEC-PERF-001.
	entities, materialise_ok := tutor_model.materialise(trace, index, context.allocator)
	if !materialise_ok {
		fmt.eprintln("TRACE_CORRUPT: the step could not be reconstructed from its keyframe.")
		return 1
	}
	defer delete(entities)

	fmt.print(tutor_render.step(trace, index, entities, style, context.temp_allocator))

	if index == len(trace.steps) - 1 {
		fmt.println()
		fmt.println(tutor_model.describe_termination(trace, context.temp_allocator))
	}
	return 0
}
