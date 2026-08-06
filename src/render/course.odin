// The chrome around a rendered screen: a progress bar, the path being edited,
// and the keys.
//
// It lives HERE, beside the step renderer, because SPEC-TUI-051 says there is
// one formatter. A progress bar drawn by the loop would be a second one, and it
// would be the one nobody has a golden for. Everything below is a pure string
// function over numbers and flags, so a test reads the bar the way a student
// sees it.
package tutor_render

import "core:fmt"
import "core:strings"

// BAR_WIDTH is the inside of the brackets, in characters.
//
// Fixed, not measured. The terminal's width is not asked for because the bar
// must be the same in a golden, in a pipe, and on a screen, and a bar that
// changes shape with the window teaches nothing extra. It fits MIN_COLUMNS.
BAR_WIDTH :: 40

// Footer is everything the loop knows and the student needs to see.
Footer :: struct {
	// done and total count exercises, not assertions.
	done:     int,
	total:    int,
	// path is the file the student edits, shown so it can be opened.
	path:     string,
	// solved offers `n`. Until the exercise passes there is nothing to move on
	// FROM, and rustlings hides the key for the same reason.
	solved:   bool,
	// showable offers `t`: a step the picture can be opened at (SPEC-EX-020).
	showable: bool,
	// width overrides BAR_WIDTH. Zero means the constant.
	width:    int,
}

// progress_bar is `[####>-------------]`.
//
// The `>` is the position, and it is always drawn: at zero the bar is not empty
// but pointing at the start. A student who has finished nothing has still begun.
progress_bar :: proc(done, total, width: int, allocator := context.temp_allocator) -> string {
	inside := width > 0 ? width : BAR_WIDTH
	if inside < 3 {
		inside = 3
	}

	filled := 0
	if total > 0 {
		filled = done * inside / total
	}
	filled = clamp(filled, 0, inside - 1)

	b := strings.builder_make(allocator)
	strings.write_byte(&b, '[')
	for _ in 0 ..< filled {
		strings.write_byte(&b, '#')
	}
	strings.write_byte(&b, '>')
	for _ in 0 ..< inside - filled - 1 {
		strings.write_byte(&b, '-')
	}
	strings.write_byte(&b, ']')
	return strings.to_string(b)
}

// key_bar names every key that does something right now.
//
// A key that is not offered is not on the bar. Showing `n` on an unsolved
// exercise would be an instruction the tool refuses to obey.
key_bar :: proc(solved, showable: bool, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	if solved {
		strings.write_string(&b, "n:next / ")
	}
	strings.write_string(&b, "h:hint / ")
	if showable {
		// The key this project exists for: not "wrong", but a picture of the
		// step where it went wrong (SPEC-EX-020).
		strings.write_string(&b, "t:show me / ")
	}
	strings.write_string(&b, "l:list / c:check all / x:reset / q:quit ?")
	return strings.to_string(b)
}

// footer is the block that sits under every screen of the loop.
footer :: proc(f: Footer, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	fmt.sbprintf(
		&b, "Progress: %s  %d/%d\n",
		progress_bar(f.done, f.total, f.width, allocator), f.done, f.total,
	)
	fmt.sbprintf(&b, "Current exercise: %s\n\n", f.path)
	strings.write_string(&b, key_bar(f.solved, f.showable, allocator))
	return strings.to_string(b)
}

// WELCOME is shown once, on the first run of a course.
//
// Four paragraphs, and none of them explains Odin. What a student cannot guess
// is how THIS tool behaves: that it watches the file, that it never edits it,
// that a failure opens a picture rather than a message, and that nothing here
// runs their program more than once per save.
WELCOME :: `Welcome to odin-tutor.

1. You solve exercises. Each one has a start.odin with something missing or
   wrong in it. Fix it and save. That is the whole loop — this tool never edits
   your file, and never moves on without you.

2. Keep your editor open on the directory this course was created in. The path
   of the exercise you are on is always shown under the progress bar. Save it and
   the exercise re-runs by itself.

3. When an assertion fails, press ` + "`t`" + `. Your program is run once under a debugger
   and you get a picture of memory at the step that decided it — which variable
   held what, which pointer pointed where. A compiler can only tell you that you
   are wrong. This can show you why.

4. Press ` + "`h`" + ` for a hint, ` + "`l`" + ` for the whole list, ` + "`x`" + ` to put an exercise back the way
   it started, and ` + "`q`" + ` to stop. Your progress is remembered.`
