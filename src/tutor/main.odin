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
import tutor_exercise "../exercise"
import tutor_model "../model"
import tutor_obs "../obs"
import tutor_preflight "../preflight"
import tutor_render "../render"
import tutor_toolchain "../toolchain"
import tutor_tui "../tui"

USAGE :: `odin-tutor — see what your Odin program does to memory

  odin-tutor init [directory]
      Copy the exercises into a directory of your own — `+"`odin-tutor/`"+` unless you
      name another. Do this first. Everything below then works from inside it,
      and the course's own tree is never written to.

  odin-tutor
      Start. Picks up where you left off, watches the file you are editing, and
      re-runs it every time you save. You never type an exercise name. Keys:
      n next, h hint, t show me, l list, c check all, x reset, q quit.

  odin-tutor list
      Every exercise, done and not done.

  odin-tutor hint
      The next hint for the exercise you are on.

  odin-tutor reset
      Put the exercise you are on back the way it started.

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

  odin-tutor check <exercise-dir> [--entry <file>] [--watch]
      Build the exercise's entry file, trace it, and report every assertion.
      --watch re-runs when the file changes.

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
		// No arguments is the STUDENT'S command, not an error. A course that
		// answers a bare name with a usage message has told the student to go
		// and read something before they may begin.
		os.exit(cmd_course(tutor_exercise.locate(context.allocator)))
	}

	switch args[0] {
	case "init":
		destination := len(args) > 1 ? args[1] : DEFAULT_COURSE_DIRECTORY
		os.exit(cmd_init(destination))
	case "list":
		os.exit(cmd_list(tutor_exercise.locate(context.allocator)))
	case "hint":
		os.exit(cmd_hint(tutor_exercise.locate(context.allocator)))
	case "reset":
		os.exit(cmd_reset(tutor_exercise.locate(context.allocator)))
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
	case "check":
		if len(args) < 2 {
			fmt.eprintln("check needs an exercise directory")
			os.exit(2)
		}
		entry_override := ""
		watch := false
		i := 2
		for i < len(args) {
			switch args[i] {
			case "--watch":
				watch = true
			case "--entry":
				if i + 1 >= len(args) {
					fmt.eprintln("--entry needs a file name")
					os.exit(2)
				}
				i += 1
				entry_override = args[i]
			case:
				fmt.eprintfln("unknown option: %s", args[i])
				os.exit(2)
			}
			i += 1
		}
		os.exit(cmd_check(args[1], entry_override, watch))
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
	stdout_path := strings.concatenate({trace_path, ".stdout"}, context.temp_allocator)
	adapter_path := adapter_location(context.temp_allocator)

	diagnostics, trace_failure := tutor_toolchain.trace(
		tutor_toolchain.Trace_Request{
			executable        = built.executable,
			source_path       = source_path,
			observations_path = observations_path,
			stdout_path       = stdout_path,
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
// Three NAMED places, tried in order, and the working directory is not one of
// them. An adapter found by searching where the student happens to be standing
// is an adapter an exercise could replace — and it runs inside the debugger
// (SPEC-SAFE-040).
//
//   1. TUTOR_ADAPTER, so a test can point at a copy and so a packager can
//      override without patching the binary.
//   2. Beside the executable, which is where an installed build puts it.
//   3. The repository layout, which is where a contributor runs from.
//
// The order matters: an installed copy must win over a repository checkout that
// happens to be the working directory, or a student with the source cloned gets
// a different adapter from the one they installed.
adapter_location :: proc(allocator := context.allocator) -> string {
	if from_env := os.get_env("TUTOR_ADAPTER", context.temp_allocator); from_env != "" {
		return strings.clone(from_env, allocator)
	}

	if len(os.args) > 0 {
		beside := filepath.dir(os.args[0])
		for relative in ([]string{"gdb_extractor.py", "adapter/gdb_extractor.py"}) {
			candidate, err := filepath.join({beside, relative}, context.temp_allocator)
			if err == nil && os.exists(candidate) {
				return strings.clone(candidate, allocator)
			}
		}
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

DEFAULT_COURSE_DIRECTORY :: "odin-tutor"

// course_source finds the exercises `init` copies FROM.
//
// The same three named places as adapter_location, and for the same reason: a
// course found by searching where the student happens to be standing is a course
// an unrelated directory can replace. The order puts an installed copy first, so
// a student who also has the repository cloned still gets the installed one.
course_source :: proc(allocator := context.allocator) -> string {
	if from_env := os.get_env("TUTOR_EXERCISES", context.temp_allocator); from_env != "" {
		return strings.clone(from_env, allocator)
	}
	if len(os.args) > 0 {
		beside := filepath.dir(os.args[0])
		candidate, err := filepath.join({beside, "exercises"}, context.temp_allocator)
		if err == nil && os.exists(candidate) {
			return strings.clone(candidate, allocator)
		}
	}
	return strings.clone("exercises", allocator)
}

// cmd_init copies the course into a directory of the student's own.
//
// The first thing anyone runs, and the one command here that changes how the
// tool is used rather than how it looks: before it, the only way to do the
// exercises was to edit them inside the repository, where the student's answers
// and the course's history were the same tree.
cmd_init :: proc(destination: string) -> int {
	source := course_source(context.temp_allocator)
	fmt.printfln("This will create %s/, which will hold your copy of the exercises.", destination)

	err := tutor_exercise.create(destination, source, context.temp_allocator)
	if err != .None {
		fmt.eprintln(tutor_exercise.explain_create(err, destination, context.temp_allocator))
		return 1
	}

	copied, join_err := filepath.join({destination, "exercises"}, context.temp_allocator)
	if join_err != nil {
		copied = destination
	}
	found := tutor_exercise.discover_at(copied, context.temp_allocator)
	fmt.println()
	fmt.printfln("Done — %d exercises.", len(found))
	fmt.println()
	fmt.printfln("  cd %s", destination)
	fmt.println("  odin-tutor")
	fmt.println()
	fmt.println("Open your editor on that directory. Nothing outside it is written to,")
	fmt.println("and nothing in it is written to by this tool unless you press x to reset.")
	return 0
}

// Loop is one run of the course, and everything the screen needs to redraw
// without running the student's program again.
Loop :: struct {
	course:       tutor_exercise.Course,
	// interactive is false when there is no terminal to read keys from — a pipe,
	// a test, a CI job. The loop still teaches; it just cannot be answered.
	interactive:  bool,
	entry:        tutor_exercise.Entry,
	entry_path:   string,
	// shown is entry_path as the student would type it: relative to the course
	// they are in. The absolute path is what every other procedure here needs
	// and is the wrong thing to put under a progress bar.
	shown:        string,
	done, total:  int,
	results:      []tutor_exercise.Result,
	// ran says the program built and traced. Without it there is nothing to
	// show a picture of, whatever the assertions would have said.
	ran:          bool,
	observations: string,
	solved:       bool,
	// step is where `t` opens the picture: the step that decided the first
	// problem, or the first step when there is no problem.
	step:         int,
}

// cmd_course is the loop from EXERCISE-SPEC.md §3.
//
// Pick the next unfinished exercise, watch the file the student edits, and on
// every save: build, trace, validate. The student never names an exercise, and
// never asks what to do next — that is the whole difference between a validator
// and a course.
//
// It does NOT advance by itself. When every assertion passes it says so, points
// at the reference solution, and waits for `n`. That is a decision, recorded in
// ROADMAP Phase 5b: a solved exercise is the one moment the student can change
// a line and watch the picture change with it, and a loop that moves on has
// taken that away to save them one keypress.
cmd_course :: proc(course: tutor_exercise.Course) -> int {
	if len(tutor_exercise.discover_at(course.exercises, context.temp_allocator)) == 0 {
		fmt.eprintfln("NO_EXERCISES: no exercises found under %s/.", course.exercises)
		fmt.eprintln("Run `odin-tutor init` to make yourself a copy of the course, then run this")
		fmt.eprintln("from inside it.")
		return 1
	}

	loop := Loop{course = course}

	// The keyboard, not the screen: the compiler's diagnostics belong in the
	// scrollback where the student can page back through them, so this session
	// never takes the alternate screen.
	session: tutor_tui.Session
	loop.interactive = tutor_tui.enter(&session, .Keys)
	defer tutor_tui.leave(&session)

	welcome(&loop)

	for {
		entries := tutor_exercise.discover(course, context.allocator)
		entry, remaining := tutor_exercise.next_unfinished(entries)
		if !remaining {
			fmt.println()
			fmt.printfln("All %d exercises are done. Nothing left to teach you here.", len(entries))
			return 0
		}

		loop.entry = entry
		loop.total = len(entries)
		loop.done = 0
		for e in entries {
			if e.done {
				loop.done += 1
			}
		}
		path, path_err := filepath.join(
			{entry.directory, entry.exercise.entry}, context.allocator,
		)
		if path_err != nil {
			fmt.eprintln("BAD_PATH: the entry file could not be resolved.")
			return 1
		}
		loop.entry_path = path
		loop.shown = inside_course(course, path)

		switch attempt(&loop, &session) {
		case .Advance:
			marked := tutor_exercise.progress_load(course, context.allocator)
			tutor_exercise.progress_mark(&marked, entry.exercise.id, context.allocator)
			if !tutor_exercise.progress_save(course, marked) {
				fmt.eprintln("PROGRESS_UNWRITABLE: could not record that you finished this one.")
			}
		case .Quit:
			return 0
		}
	}
}

Outcome :: enum {
	Advance,
	Quit,
}

// inside_course shortens a path to the course it is in.
//
// `exercises/04-structs/start.odin` is a path the student can type, open, and
// recognise. The absolute one is the same information with the part they
// already know spelled out, on a line that is on screen at all times.
inside_course :: proc(course: tutor_exercise.Course, path: string) -> string {
	if course.root == "" || !strings.has_prefix(path, course.root) {
		return path
	}
	return strings.trim_left(path[len(course.root):], "/")
}

// attempt stays on one exercise until it is finished or the student leaves.
//
// Two things can interrupt the wait: a save, and a key. They are polled in the
// same loop because the read gives up after a tenth of a second, so neither has
// to wait for the other — the student can press `h` while the file is untouched,
// and a save is noticed while no key is being pressed.
attempt :: proc(l: ^Loop, session: ^tutor_tui.Session) -> Outcome {
	turn: for {
		evaluate(l)

		if !l.interactive {
			// No keyboard, so nobody to ask. Advancing on a pass is the only
			// behaviour left that makes progress; it is stated rather than
			// silently different from the interactive loop.
			if l.solved {
				fmt.println("Done. Moving on (no terminal to wait for a key on).")
				return .Advance
			}
			fmt.println()
			fmt.println("watching for your next save — Ctrl-C to stop")
			await_save(l)
			continue turn
		}

		footer(l)
		last := modified_at(l.entry_path)
		for {
			if now := modified_at(l.entry_path); now != last && now != 0 {
				continue turn
			}
			key := tutor_tui.poll_key()
			if key == 0 {
				continue
			}
			switch key {
			case 'q', 'Q':
				return .Quit
			case 'n', 'N':
				if l.solved {
					return .Advance
				}
				// Not an error, and not silence either: the key is not on the
				// bar because it does nothing yet, and saying so is shorter
				// than letting the student wonder whether it was read.
				fmt.println("Not done yet — `n` moves on once every assertion passes.")
				footer(l)
			case 'h', 'H':
				show_hint(l)
				footer(l)
			case 'l', 'L':
				show_list(l)
				footer(l)
			case 'c', 'C':
				check_all(l)
				footer(l)
			case 'x', 'X':
				if restore(l) {
					continue turn
				}
				footer(l)
			case 't', 'T':
				show_picture(l, session)
				report(l)
				footer(l)
			case:
				footer(l)
			}
		}
	}
}

// await_save blocks until the file changes.
//
// Polling on the modification time, because the alternative is a per-platform
// notification API and a dependency that Rule 10 would make us justify for every
// platform, to save a 300 ms wait.
await_save :: proc(l: ^Loop) {
	last := modified_at(l.entry_path)
	for {
		time.sleep(300 * time.Millisecond)
		now := modified_at(l.entry_path)
		if now != last && now != 0 {
			return
		}
	}
}

// welcome is the first-run explanation, shown once per course.
welcome :: proc(l: ^Loop) {
	progress := tutor_exercise.progress_load(l.course, context.allocator)
	if progress.welcomed {
		return
	}
	if l.interactive {
		os.write_string(os.stdout, tutor_tui.CLEAR)
	}
	fmt.println(tutor_render.WELCOME)
	if l.interactive {
		fmt.println()
		fmt.println("Press any key to begin.")
		for tutor_tui.poll_key() == 0 {
		}
	}
	progress.welcomed = true
	if !tutor_exercise.progress_save(l.course, progress) {
		// Not fatal. Seeing this twice is a smaller failure than refusing to
		// start because a state file could not be written.
		fmt.eprintln("PROGRESS_UNWRITABLE: this introduction will be shown again next time.")
	}
}

// evaluate is one turn of the loop: build, trace, validate, and draw.
//
// The screen is cleared BEFORE the program is built, never after. The compiler
// writes its diagnostics as it goes, and a redraw that happened afterwards would
// wipe the one thing on screen the student most needs to read.
evaluate :: proc(l: ^Loop) {
	// Everything a turn allocates is temporary and lives exactly one turn. The
	// loop's own strings are on the heap allocator, so this is safe here and
	// nowhere further in.
	free_all(context.temp_allocator)

	clear(l)
	header(l)

	results, observations, ok := check_once(l.entry.exercise, l.entry_path)
	l.results = results
	l.observations = observations
	l.ran = ok
	l.solved = ok && tutor_exercise.passed(results)
	l.step = 1
	for r in results {
		if r.verdict != .Pass && r.step > 0 {
			l.step = r.step
			break
		}
	}
	verdicts(l)
}

// report redraws the same screen without running anything, for when the step
// player has been over the top of it.
report :: proc(l: ^Loop) {
	clear(l)
	header(l)
	verdicts(l)
}

clear :: proc(l: ^Loop) {
	if l.interactive {
		os.write_string(os.stdout, tutor_tui.CLEAR)
	}
}

// header is which exercise this is and what it is for.
header :: proc(l: ^Loop) {
	fmt.printfln("── %s ── %s", l.entry.exercise.id, l.entry.exercise.title)
	fmt.println(l.entry.exercise.objective)

	// Advisory, never a refusal. A student who jumps ahead is not wrong.
	progress := tutor_exercise.progress_load(l.course, context.temp_allocator)
	missing := tutor_exercise.missing_requirements(l.entry, progress, context.temp_allocator)
	if len(missing) > 0 {
		fmt.printfln("(this one builds on %s, which you have not finished — carry on if you like)",
			strings.join(missing, ", ", context.temp_allocator))
	}
	fmt.println()
}

// verdicts is what the last run found, and what to do about it.
verdicts :: proc(l: ^Loop) {
	if !l.ran {
		// The compiler's or the debugger's own message has already been printed,
		// by whatever failed. Repeating it in other words would only give the
		// student two accounts of one problem.
		return
	}

	undetermined := 0
	// The first problem THAT HAPPENED AT A STEP, which is not always the first
	// problem: "no step satisfied this" is a verdict about the whole run and has
	// no step to open. Offering to show step 0 would open the wrong picture.
	first_problem := -1
	for r, i in l.results {
		switch r.verdict {
		case .Pass:
			fmt.printfln("  pass          %s", r.id)
		case .Fail:
			fmt.printfln("  FAIL          %s  %s", r.id, r.reason)
		case .Undetermined:
			undetermined += 1
			fmt.printfln("  undetermined  %s  %s", r.id, r.reason)
		}
		if r.verdict != .Pass && r.step > 0 && first_problem < 0 {
			first_problem = i
		}
	}
	fmt.println()

	if l.solved {
		fmt.println("Exercise done ✓")
		if solution := solution_path(l); solution != "" {
			// It exists in every exercise and was never mentioned before this.
			fmt.printfln("Solution for comparison: %s", solution)
		}
		fmt.println("When done experimenting, enter `n` to move on.")
		return
	}

	// Point at the step, not just at the assertion. The Result carries which
	// step decided it, and a student who can open the picture there is being
	// shown the answer rather than told about it (SPEC-EX-020).
	if first_problem >= 0 {
		fmt.printfln(
			"%s was decided at step %d — press `t` to look at it.",
			l.results[first_problem].id, l.results[first_problem].step,
		)
	} else {
		fmt.println("Press `t` to watch the program you just ran, step by step.")
	}
	if undetermined > 0 {
		fmt.println(
			"Some assertions could not be decided. That is a limit of this tool, " +
			"not a mistake in your program.",
		)
	}
}

// footer is the progress bar, the path, and the keys.
//
// Every line of it comes from tutor_render, which is the single formatter
// (SPEC-TUI-051). This procedure decides WHICH keys are live and nothing about
// how any of it looks.
footer :: proc(l: ^Loop) {
	if !l.interactive {
		return
	}
	fmt.println()
	fmt.println(
		tutor_render.footer(
			tutor_render.Footer {
				done = l.done,
				total = l.total,
				path = l.shown,
				solved = l.solved,
				showable = l.ran,
			},
			context.temp_allocator,
		),
	)
}

solution_path :: proc(l: ^Loop) -> string {
	path, err := filepath.join({l.entry.directory, "solution.odin"}, context.temp_allocator)
	if err != nil || !os.exists(path) {
		return ""
	}
	return inside_course(l.course, path)
}

show_hint :: proc(l: ^Loop) {
	fmt.println()
	if len(l.entry.exercise.hints) == 0 {
		fmt.printfln("%s has no hints written yet.", l.entry.exercise.id)
		return
	}
	for name in l.entry.exercise.hints {
		path, err := filepath.join({l.entry.directory, name}, context.temp_allocator)
		if err != nil {
			continue
		}
		data, read_err := os.read_entire_file(path, context.temp_allocator)
		if read_err != nil {
			fmt.eprintfln("HINT_UNREADABLE: %s is named by the exercise and is not there.", path)
			return
		}
		fmt.println(string(data))
		return
	}
}

show_list :: proc(l: ^Loop) {
	fmt.println()
	print_list(l.course)
}

// check_all runs every exercise, and records the ones that pass.
//
// The student who has been editing several files ahead gets them all counted,
// which is the only way the count can be honest about work the loop did not
// watch happen.
check_all :: proc(l: ^Loop) {
	entries := tutor_exercise.discover(l.course, context.temp_allocator)
	fmt.println()
	fmt.printfln("Checking all %d exercises. Each one is built and run — this takes a while.", len(entries))
	fmt.println()

	progress := tutor_exercise.progress_load(l.course, context.allocator)
	changed := false
	for entry in entries {
		path, err := filepath.join(
			{entry.directory, entry.exercise.entry}, context.temp_allocator,
		)
		if err != nil {
			continue
		}
		results, _, ok := check_once(entry.exercise, path)
		if ok && tutor_exercise.passed(results) {
			fmt.printfln("  pass  %s", entry.exercise.id)
			if !tutor_exercise.is_done(progress, entry.exercise.id) {
				tutor_exercise.progress_mark(&progress, entry.exercise.id, context.allocator)
				changed = true
			}
		} else {
			fmt.printfln("  not   %s", entry.exercise.id)
		}
	}
	if changed && !tutor_exercise.progress_save(l.course, progress) {
		fmt.eprintln("PROGRESS_UNWRITABLE: what just passed was not recorded.")
	}
	recount(l)
}

// recount refreshes the bar after something other than this exercise changed it.
recount :: proc(l: ^Loop) {
	entries := tutor_exercise.discover(l.course, context.temp_allocator)
	l.total = len(entries)
	l.done = 0
	for e in entries {
		if e.done {
			l.done += 1
		}
	}
}

// restore puts the exercise back the way it was handed over.
restore :: proc(l: ^Loop) -> bool {
	fmt.println()
	switch tutor_exercise.reset(l.course, l.entry) {
	case .None:
		fmt.printfln("Reset %s to the way it started.", l.shown)
		return true
	case .No_Original:
		// Honest about the one case it cannot serve, rather than inventing a
		// file or telling the student to learn git for it.
		fmt.println(
			"NO_ORIGINAL: this course was not made by `odin-tutor init`, so there is no " +
			"untouched copy to restore from.",
		)
	case .Unwritable:
		fmt.printfln("UNWRITABLE: could not write %s.", l.entry_path)
	}
	return false
}

// show_picture opens the step player where the assertion was decided.
//
// The trace is rebuilt from the observation stream the last run already wrote,
// so pressing `t` runs nothing: no compiler, no debugger, no second execution of
// the student's program (SPEC-PERF-001).
show_picture :: proc(l: ^Loop, session: ^tutor_tui.Session) {
	if !l.ran {
		return
	}
	data, read_err := os.read_entire_file(l.observations, context.temp_allocator)
	if read_err != nil {
		fmt.eprintln("OBSERVATIONS_MISSING: there is nothing recorded to show.")
		return
	}
	stream, decode_err := tutor_obs.decode(data)
	if decode_err != .None {
		fmt.eprintln("OBSERVATION_MALFORMED: the recorded run could not be read back.")
		return
	}

	assembly: tutor_model.Assembly
	if tutor_model.assembly_init(&assembly) != nil {
		fmt.eprintln("OUT_OF_MEMORY: could not reserve the assembly arena.")
		return
	}
	defer tutor_model.assembly_destroy(&assembly)

	trace, build_err := tutor_model.assemble(&assembly, stream)
	if build_err != .None {
		fmt.eprintln("BUDGET_DISAGREEMENT: the recorded run cannot be turned into a picture.")
		return
	}

	source: []string
	if text, err := os.read_entire_file(l.entry_path, context.temp_allocator); err == nil {
		source = strings.split_lines(string(text), context.temp_allocator)
	}

	// The player owns the terminal while it is up: it takes the whole screen and
	// blocks on each key, which is the opposite of what this loop needs.
	tutor_tui.leave(session)
	tutor_tui.run(trace, source, tutor_render.FANCY, l.step - 1)
	l.interactive = tutor_tui.enter(session, .Keys)
}

// cmd_list shows the whole course, done and not done.
cmd_list :: proc(course: tutor_exercise.Course) -> int {
	return print_list(course)
}

print_list :: proc(course: tutor_exercise.Course) -> int {
	entries := tutor_exercise.discover(course, context.temp_allocator)
	if len(entries) == 0 {
		fmt.eprintfln("NO_EXERCISES: no exercises found under %s/.", course.exercises)
		fmt.eprintln("Run `odin-tutor init` to make yourself a copy of the course.")
		return 1
	}
	done := 0
	for entry in entries {
		mark := entry.done ? "done" : "    "
		if entry.done {
			done += 1
		}
		fmt.printfln("  %s  %-28s %s", mark, entry.exercise.id, entry.exercise.title)
	}
	fmt.println()
	fmt.printfln(
		"Progress: %s  %d/%d",
		tutor_render.progress_bar(done, len(entries), 0, context.temp_allocator),
		done, len(entries),
	)
	fmt.printfln("%d of %d finished.", done, len(entries))
	return 0
}

// cmd_hint prints the next hint for the exercise the student is on.
cmd_hint :: proc(course: tutor_exercise.Course) -> int {
	entries := tutor_exercise.discover(course, context.temp_allocator)
	entry, remaining := tutor_exercise.next_unfinished(entries)
	if !remaining {
		fmt.println("Nothing left to hint at — every exercise is done.")
		return 0
	}
	if len(entry.exercise.hints) == 0 {
		fmt.printfln("%s has no hints written yet.", entry.exercise.id)
		return 0
	}
	for name in entry.exercise.hints {
		path, err := filepath.join({entry.directory, name}, context.temp_allocator)
		if err != nil {
			continue
		}
		data, read_err := os.read_entire_file(path, context.temp_allocator)
		if read_err != nil {
			fmt.eprintfln("HINT_UNREADABLE: %s is named by the exercise and is not there.", path)
			return 1
		}
		fmt.println(string(data))
		return 0
	}
	return 0
}

// cmd_reset puts the exercise the student is on back to its starting state.
//
// The same thing `x` does inside the loop, for the student who has already quit
// and does not want to start the loop again to undo one file.
cmd_reset :: proc(course: tutor_exercise.Course) -> int {
	entries := tutor_exercise.discover(course, context.temp_allocator)
	entry, remaining := tutor_exercise.next_unfinished(entries)
	if !remaining {
		fmt.println("Every exercise is done — there is nothing you are in the middle of.")
		return 0
	}
	switch tutor_exercise.reset(course, entry) {
	case .None:
		fmt.printfln("Reset %s to the way it started.", entry.exercise.id)
		return 0
	case .No_Original:
		fmt.eprintln(
			"NO_ORIGINAL: this course was not made by `odin-tutor init`, so there is no " +
			"untouched copy to restore from.",
		)
		return 1
	case .Unwritable:
		fmt.eprintfln("UNWRITABLE: could not write inside %s.", entry.directory)
		return 1
	}
	return 1
}

// cmd_check builds an exercise's entry file, traces it, and reports every
// assertion.
//
// The verdicts are THREE. `undetermined` blocks the pass and is never rendered
// as the student's failure: missing evidence has causes that are not their
// doing (SPEC-VAL-001, SPEC-VAL-003).
cmd_check :: proc(directory, entry_override: string, watch: bool) -> int {
	manifest_path, join_err := filepath.join(
		{directory, "exercise.json"}, context.temp_allocator,
	)
	if join_err != nil {
		fmt.eprintln("BAD_PATH: the exercise directory could not be read.")
		return 1
	}
	data, read_err := os.read_entire_file(manifest_path, context.temp_allocator)
	if read_err != nil {
		fmt.eprintfln("EXERCISE_UNREADABLE: could not read %s", manifest_path)
		return 1
	}
	exercise, load_err := tutor_exercise.load(data, context.temp_allocator)
	switch load_err {
	case .None:
	case .Malformed_Json:
		fmt.eprintln("EXERCISE_MALFORMED: exercise.json is not valid JSON.")
		return 1
	case .No_Entry:
		fmt.eprintln("EXERCISE_INCOMPLETE: the exercise names no entry file.")
		return 1
	case .No_Assertions:
		// An exercise with no assertions accepts every solution, including the
		// wrong ones. SPEC-EX-052 requires the opposite.
		fmt.eprintln("EXERCISE_INCOMPLETE: the exercise has no assertions, so it would accept anything.")
		return 1
	}

	entry := entry_override != "" ? entry_override : exercise.entry
	entry_path, entry_err := filepath.join({directory, entry}, context.temp_allocator)
	if entry_err != nil {
		fmt.eprintln("BAD_PATH: the entry file could not be resolved.")
		return 1
	}

	if !watch {
		return run_check(exercise, entry_path)
	}

	// Watch mode: re-run when the file changes. Polling on the modification
	// time, because the alternative is a per-platform notification API and a
	// dependency, which Rule 10 would make us justify for every platform.
	last := modified_at(entry_path)
	run_check(exercise, entry_path)
	fmt.println("\nwatching", entry_path, "— press Ctrl-C to stop")
	for {
		time.sleep(300 * time.Millisecond)
		now := modified_at(entry_path)
		if now == last {
			continue
		}
		last = now
		fmt.println()
		run_check(exercise, entry_path)
		fmt.println("\nwatching", entry_path, "— press Ctrl-C to stop")
	}
}

modified_at :: proc(path: string) -> i64 {
	info, err := os.stat(path, context.temp_allocator)
	if err != nil {
		return 0
	}
	return i64(info.modification_time._nsec)
}

// check_once is build, trace, validate — and no printing at all.
//
// Split out so the one-shot `check` command and the student's loop share it.
// Two implementations of "run this exercise" would drift, and the one the
// student uses is the one that matters.
//
// It returns the observation stream's path as well as the verdicts, so that the
// loop's `t` can draw the picture from the run that just happened rather than
// running the student's program a second time.
check_once :: proc(
	exercise: tutor_exercise.Exercise,
	entry_path: string,
) -> (
	results: []tutor_exercise.Result,
	observations_path: string,
	ok: bool,
) {
	report, versions := examine(context.temp_allocator)
	if report.failure != .None {
		fmt.eprintln(tutor_preflight.explain(report.failure, context.temp_allocator))
		return nil, "", false
	}

	built, build_failure := tutor_toolchain.build(entry_path, versions, context.temp_allocator)
	if build_failure != .None {
		// The compiler's own message, unchanged. It names the line, which is the
		// part the student needs, and rewriting it would drop that.
		if built.diagnostics != "" {
			fmt.eprint(built.diagnostics)
		}
		fmt.eprintln(tutor_toolchain.explain(build_failure, context.temp_allocator))
		return nil, "", false
	}

	work := strings.concatenate({built.executable, ".check"}, context.temp_allocator)
	observations_path = strings.concatenate({work, ".observations"}, context.temp_allocator)
	_, trace_failure := tutor_toolchain.trace(
		tutor_toolchain.Trace_Request{
			executable        = built.executable,
			source_path       = entry_path,
			observations_path = observations_path,
			stdout_path       = strings.concatenate({work, ".stdout"}, context.temp_allocator),
			adapter_path      = adapter_location(context.temp_allocator),
			versions          = versions,
		},
		context.temp_allocator,
	)
	if trace_failure != .None {
		fmt.eprintln(tutor_toolchain.explain(trace_failure, context.temp_allocator))
		return nil, "", false
	}

	observations, obs_err := os.read_entire_file(observations_path, context.temp_allocator)
	if obs_err != nil {
		fmt.eprintln("OBSERVATIONS_MISSING: the adapter wrote nothing.")
		return nil, "", false
	}
	stream, decode_err := tutor_obs.decode(observations)
	if decode_err != .None {
		fmt.eprintln("OBSERVATION_MALFORMED: the adapter's output is not valid JSON.")
		return nil, "", false
	}

	assembly: tutor_model.Assembly
	if tutor_model.assembly_init(&assembly) != nil {
		fmt.eprintln("OUT_OF_MEMORY: could not reserve the assembly arena.")
		return nil, "", false
	}
	defer tutor_model.assembly_destroy(&assembly)

	trace, build_err := tutor_model.assemble(&assembly, stream)
	if build_err != .None {
		fmt.eprintln("BUDGET_DISAGREEMENT: the adapter reports different limits from this build.")
		return nil, "", false
	}

	return tutor_exercise.evaluate(exercise, trace, context.temp_allocator),
		observations_path,
		true
}

run_check :: proc(exercise: tutor_exercise.Exercise, entry_path: string) -> int {
	results, _, ok := check_once(exercise, entry_path)
	if !ok {
		return 1
	}

	fmt.printfln("%s — %s", exercise.id, exercise.title)
	fmt.println(exercise.objective)
	fmt.println()
	undetermined := 0
	for r in results {
		switch r.verdict {
		case .Pass:
			fmt.printfln("  pass          %-4s", r.id)
		case .Fail:
			fmt.printfln("  FAIL          %-4s  %s", r.id, r.reason)
		case .Undetermined:
			undetermined += 1
			fmt.printfln("  undetermined  %-4s  %s", r.id, r.reason)
		}
	}
	fmt.println()

	if tutor_exercise.passed(results) {
		fmt.println("Done. Every assertion passed.")
		return 0
	}
	if undetermined > 0 {
		// Never rendered as a failure of the solution. The student is told what
		// to do about it, and it is not "change your logic".
		fmt.println(
			"Not done. Some assertions could not be decided — that is a limit of the tool, " +
			"not a mistake in your program. Shortening the program usually resolves it.",
		)
	} else {
		fmt.println("Not done yet.")
	}
	return 1
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
