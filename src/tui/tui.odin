// Package tutor_tui is the step player: the screen a student actually uses.
//
// It formats nothing. Every line it shows comes from tutor_render, because two
// implementations of one screen drift and the one nobody looks at drifts first
// (SPEC-TUI-051). This package owns the terminal, the keys, and the redraw —
// nothing else.
//
// No terminal framework. Odin has no mature one, the layout is columns and
// lists, and there is no event loop beyond "read a key, redraw"
// (ADR-010, SPEC-TUI-060). The ANSI subset used is the constant block below and
// nowhere else.
package tutor_tui

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"
import tutor_model "../model"
import tutor_render "../render"

// The whole ANSI subset, in one place. See SPEC-TUI-060.
ALTERNATE_ON :: "\x1b[?1049h"
ALTERNATE_OFF :: "\x1b[?1049l"
CURSOR_HIDE :: "\x1b[?25l"
CURSOR_SHOW :: "\x1b[?25h"
CLEAR :: "\x1b[2J\x1b[H"

// Mode says how much of the terminal a session takes.
//
// The step player takes all of it: a whole screen, redrawn, given back on exit.
// The exercise loop takes only the keyboard — it shares the scrollback with the
// compiler's diagnostics, which the student needs to be able to scroll up to.
// One session type, because there is one thing to restore either way.
Mode :: enum {
	Screen,
	Keys,
}

// Session owns the terminal's state so it can be given back.
//
// The saved termios is a package-level value on purpose: a signal handler
// cannot take a parameter, and a terminal left in raw mode after a crash is a
// shell the student has to close. Restoration must not depend on reaching the
// end of a procedure.
Session :: struct {
	saved:   posix.termios,
	entered: bool,
	mode:    Mode,
}

@(private)
active: ^Session

// enter puts the terminal into raw mode, and in Screen mode switches to the
// alternate screen.
enter :: proc(s: ^Session, mode := Mode.Screen) -> bool {
	if posix.tcgetattr(posix.STDIN_FILENO, &s.saved) != .OK {
		return false
	}
	raw := s.saved
	// No line buffering and no echo: a key must arrive as it is pressed, and
	// the student's keystrokes must not appear inside the drawing.
	raw.c_lflag -= {.ICANON, .ECHO}
	if mode == .Keys {
		// A read that gives up. The loop has a second thing to do — noticing
		// that the file was saved — so it cannot afford a read that blocks
		// until a key arrives. VTIME is in tenths of a second.
		raw.c_cc[.VMIN] = 0
		raw.c_cc[.VTIME] = 1
	} else {
		raw.c_cc[.VMIN] = 1
		raw.c_cc[.VTIME] = 0
	}
	if posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw) != .OK {
		return false
	}
	s.entered = true
	s.mode = mode
	active = s

	// The handler is installed AFTER the terminal is changed, so there is never
	// a window where a signal would restore state that was never saved.
	install_interrupt_handler()

	if mode == .Screen {
		os.write_string(os.stdout, ALTERNATE_ON)
		os.write_string(os.stdout, CURSOR_HIDE)
	}
	return true
}

// leave gives the terminal back exactly as it was found.
//
// Idempotent, because it is called from the normal exit path AND from the
// signal handler, and either may run first. It undoes only what `enter` did:
// writing ALTERNATE_OFF after a Keys session would scroll away the output the
// student is reading.
leave :: proc(s: ^Session) {
	if !s.entered {
		return
	}
	s.entered = false
	if s.mode == .Screen {
		os.write_string(os.stdout, CURSOR_SHOW)
		os.write_string(os.stdout, ALTERNATE_OFF)
	}
	saved := s.saved
	posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &saved)
	active = nil
}

@(private)
on_interrupt :: proc "c" (sig: posix.Signal) {
	// A terminal left in raw mode outlives the process. Restoring here is the
	// difference between an interrupt and a shell the student has to close.
	if active != nil {
		context = {}
		leave(active)
	}
	posix.exit(130)
}

@(private)
install_interrupt_handler :: proc() {
	action := posix.sigaction_t{}
	action.sa_handler = on_interrupt
	posix.sigaction(.SIGINT, &action, nil)
	posix.sigaction(.SIGTERM, &action, nil)
}

// Key is what the reader made of the bytes it got.
Key :: enum {
	None,
	Next,
	Previous,
	First,
	Last,
	Jump,
	Crash,
	Help,
	Quit,
}

// read_key turns bytes into one command.
//
// Arrow keys arrive as three bytes, `ESC [ A`. A bare ESC is not a command
// here: treating it as one would make a half-read arrow quit the session.
read_key :: proc() -> Key {
	buffer: [3]byte
	n, err := os.read(os.stdin, buffer[:1])
	if err != nil || n <= 0 {
		return .Quit
	}
	switch buffer[0] {
	case 'q', 'Q':
		return .Quit
	case 'n', ' ':
		return .Next
	case 'p':
		return .Previous
	case 'g':
		return .Jump
	case 'c':
		return .Crash
	case '?':
		return .Help
	case 0x1b:
		rest, rest_err := os.read(os.stdin, buffer[1:3])
		if rest_err != nil || rest < 2 {
			return .None
		}
		if buffer[1] != '[' {
			return .None
		}
		switch buffer[2] {
		case 'C':
			return .Next
		case 'D':
			return .Previous
		case 'H':
			return .First
		case 'F':
			return .Last
		}
		return .None
	}
	return .None
}

// poll_key returns the byte that was pressed, or 0 if none arrived.
//
// For a Keys session only, where the read gives up after a tenth of a second.
// The exercise loop interprets the byte itself: its keys are the course's
// (n, h, t, l, c, x, q), not the player's, and one enum spanning both would
// have members that are meaningless in half its uses.
poll_key :: proc() -> byte {
	buffer: [1]byte
	n, err := os.read(os.stdin, buffer[:])
	if err != nil || n <= 0 {
		return 0
	}
	return buffer[0]
}

// Player is one session over one trace.
Player :: struct {
	trace:  tutor_model.Trace,
	source: []string,
	style:  tutor_render.Style,
	index:  int,
	notice: string,
}

// draw paints one step.
//
// It re-reads the trace and nothing else. No step in the interface re-runs the
// program or the compiler: that is the whole point of recording a trace
// (SPEC-PERF-001, ROADMAP Phase 4 acceptance 5).
draw :: proc(p: ^Player) {
	entities, ok := tutor_model.materialise(p.trace, p.index, context.temp_allocator)
	if !ok {
		os.write_string(os.stdout, CLEAR)
		os.write_string(os.stdout, "TRACE_CORRUPT: this step could not be reconstructed.\n")
		return
	}

	text := tutor_render.screen(
		tutor_render.Screen {
			trace = p.trace,
			index = p.index,
			entities = entities,
			source = p.source,
			style = p.style,
			context_lines = tutor_render.DEFAULT_CONTEXT_LINES,
		},
		context.temp_allocator,
	)

	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, CLEAR)
	strings.write_string(&b, text)
	if p.notice != "" {
		fmt.sbprintf(&b, "\n%s\n", p.notice)
	}
	if p.index == len(p.trace.steps) - 1 {
		fmt.sbprintf(
			&b, "\n%s\n",
			tutor_model.describe_termination(p.trace, context.temp_allocator),
		)
	}
	strings.write_string(
		&b,
		"\n<- -> step   g jump   Home/End ends   c crash   ? help   q quit\n",
	)
	os.write_string(os.stdout, strings.to_string(b))
}

// prompt reads a line with echo on, for `g`.
prompt :: proc(p: ^Player, question: string) -> string {
	saved := active.saved
	posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &saved)
	os.write_string(os.stdout, CURSOR_SHOW)
	defer {
		raw := active.saved
		raw.c_lflag -= {.ICANON, .ECHO}
		posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw)
		os.write_string(os.stdout, CURSOR_HIDE)
	}

	os.write_string(os.stdout, question)
	buffer: [32]byte
	n, err := os.read(os.stdin, buffer[:])
	if err != nil || n <= 0 {
		return ""
	}
	return strings.clone(strings.trim_space(string(buffer[:n])), context.temp_allocator)
}

// run is the whole event loop: read a key, redraw.
//
// `start` is the step to open at, 0-based. The exercise loop uses it to open the
// picture where an assertion was decided rather than at the beginning
// (SPEC-EX-020): the student pressed `t` about one step, not about the program.
run :: proc(
	trace: tutor_model.Trace,
	source: []string,
	style: tutor_render.Style,
	start := 0,
) -> int {
	if len(trace.steps) == 0 {
		fmt.eprintln("The trace has no steps.")
		return 1
	}

	session: Session
	if !enter(&session) {
		fmt.eprintln(
			"NOT_A_TERMINAL: this needs an interactive terminal. " +
			"Use `odin-tutor render <trace.json> <step>` to print one step instead.",
		)
		return 1
	}
	// Restores on every exit from this procedure, including a panic unwinding
	// through it. See ROADMAP Phase 4 acceptance 4.
	defer leave(&session)

	last := len(trace.steps) - 1
	player := Player{
		trace = trace,
		source = source,
		style = style,
		index = clamp(start, 0, last),
	}

	for {
		draw(&player)
		switch read_key() {
		case .Quit:
			return 0
		case .Next:
			player.notice = ""
			if player.index < last {
				player.index += 1
			} else {
				player.notice = "This is the last step."
			}
		case .Previous:
			player.notice = ""
			if player.index > 0 {
				player.index -= 1
			} else {
				player.notice = "This is the first step."
			}
		case .First:
			player.notice = ""
			player.index = 0
		case .Last:
			player.notice = ""
			player.index = last
		case .Crash:
			// The second most common question a student has, and the trace
			// already marks it. See SPEC-TUI-031.
			player.notice = ""
			#partial switch trace.termination {
			case .Completed:
				player.notice = "The program ran to completion. There is no crash step."
			case:
				player.index = last
			}
		case .Jump:
			answer := prompt(&player, fmt.tprintf("jump to step (1-%d): ", last + 1))
			wanted, parsed := strconv.parse_int(answer)
			if !parsed || wanted < 1 || wanted > last + 1 {
				player.notice = fmt.tprintf("No step %s. The trace has %d.", answer, last + 1)
			} else {
				player.notice = ""
				player.index = wanted - 1
			}
		case .Help:
			player.notice = "<- -> or p/n move one step. Home and End are the ends. " +
				"g jumps. c goes to the crash. q quits."
		case .None:
		}
	}
}
