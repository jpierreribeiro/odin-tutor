// Package tutor_exercise loads exercises and evaluates their assertions.
//
// An exercise is DATA. The loader reads `exercise.json` and executes nothing
// from the exercise directory except the student's own Odin source, through the
// normal build path. Content that can execute is a different kind of artefact
// with a different review standard (SPEC-EX-001, SPEC-EX-002).
//
// The validator reads a trace. It never reads the student's source text, so it
// cannot be fooled by a program that looks right, and it cannot grade style.
// See ARCHITECTURE.md §2.
package tutor_exercise

import "core:encoding/json"
import "core:strings"
import tutor_model "../model"

// Verdict is the answer for one assertion. THREE, not two.
//
// `Undetermined` exists because missing evidence has causes that are not the
// student's fault: a budget was reached, a value was `unreadable`, a return
// value could not be attributed. Reporting those as `Fail` blames the student
// for the tool's limit, in the wrong direction (SPEC-VAL-001).
Verdict :: enum {
	Pass,
	Fail,
	Undetermined,
}

// Assertion is one claim about the trace.
Assertion :: struct {
	id:   string `json:"id"`,
	at:   string `json:"at"`,
	expr: string `json:"expr"`,
}

// Exercise is the whole `exercise.json`.
Exercise :: struct {
	id:          string      `json:"id"`,
	title:       string      `json:"title"`,
	objective:   string      `json:"objective"`,
	concepts:    []string    `json:"concepts"`,
	difficulty:  int         `json:"difficulty"`,
	requires:    []string    `json:"requires"`,
	entry:       string      `json:"entry"`,
	stdin:       string      `json:"stdin"`,
	assertions:  []Assertion `json:"assertions"`,
	hints:       []string    `json:"hints"`,
	expected_wall_ms: int    `json:"expected_wall_ms"`,
}

Load_Error :: enum {
	None,
	Malformed_Json,
	No_Assertions,
	No_Entry,
}

load :: proc(data: []byte, allocator := context.allocator) -> (Exercise, Load_Error) {
	exercise: Exercise
	if json.unmarshal(data, &exercise, allocator = allocator) != nil {
		return {}, .Malformed_Json
	}
	if exercise.entry == "" {
		return exercise, .No_Entry
	}
	if len(exercise.assertions) == 0 {
		// An exercise with no assertions passes every solution, including the
		// wrong ones. SPEC-EX-052 requires the opposite.
		return exercise, .No_Assertions
	}
	return exercise, .None
}

// Result is one evaluated assertion, with the reason when it is not a pass.
Result :: struct {
	id:      string,
	verdict: Verdict,
	// step is the 1-based step the verdict came from, or 0.
	step:    int,
	reason:  string,
}

// evaluate runs every assertion of an exercise against one trace.
evaluate :: proc(
	exercise: Exercise,
	trace: tutor_model.Trace,
	allocator := context.allocator,
) -> []Result {
	results := make([dynamic]Result, allocator)
	for assertion in exercise.assertions {
		append(&results, evaluate_one(assertion, trace, allocator))
	}
	return results[:]
}

// passed says whether the exercise is done.
//
// Only when EVERY assertion is a pass. `undetermined` blocks the pass and is
// reported with its cause, so the student knows to shorten the program rather
// than to change the logic. It is never counted as a pass (SPEC-VAL-002).
passed :: proc(results: []Result) -> bool {
	for r in results {
		if r.verdict != .Pass {
			return false
		}
	}
	return len(results) > 0
}

// --- the expression language ------------------------------------------------

// Call is one parsed `name(arg, arg)` with an optional `== literal`.
//
// A malformed expression is a LOAD error, not `undetermined`. An exercise that
// cannot be read is an authoring defect, and reporting it as missing evidence
// would hide it behind the student's program.
Call :: struct {
	name:      string,
	arguments: []string,
	compares:  bool,
	// operator is how `expected` is compared: "==", "<=", ">=", "<" or ">".
	//
	// Equality alone could not say "never more than", which is the natural
	// shape of a lesson about growth: a count that must not exceed a bound, a
	// capacity that must not be reached. Writing it as equality at one step
	// asks a weaker question, and a wrong answer that passes THROUGH the right
	// number on its way past it slips by.
	operator:  string,
	expected:  string,
}

parse :: proc(expr: string, allocator := context.temp_allocator) -> (call: Call, ok: bool) {
	text := strings.trim_space(expr)

	// Two-character operators first: `<` would otherwise swallow `<=`.
	for op in ([]string{"==", "<=", ">=", "<", ">"}) {
		comparison := strings.index(text, op)
		if comparison < 0 {
			continue
		}
		call.compares = true
		call.operator = op
		call.expected = unquote(strings.trim_space(text[comparison + len(op):]))
		text = strings.trim_space(text[:comparison])
		break
	}

	open := strings.index_byte(text, '(')
	if open < 0 || !strings.has_suffix(text, ")") {
		return call, false
	}
	call.name = strings.trim_space(text[:open])
	inside := text[open + 1:len(text) - 1]

	arguments := make([dynamic]string, allocator)
	depth := 0
	start := 0
	in_string := false
	for i in 0 ..< len(inside) {
		switch inside[i] {
		case '"':
			in_string = !in_string
		case '(':
			if !in_string {
				depth += 1
			}
		case ')':
			if !in_string {
				depth -= 1
			}
		case ',':
			if !in_string && depth == 0 {
				append(&arguments, unquote(strings.trim_space(inside[start:i])))
				start = i + 1
			}
		}
	}
	last := strings.trim_space(inside[start:])
	if last != "" {
		append(&arguments, unquote(last))
	}
	call.arguments = arguments[:]
	return call, call.name != ""
}

unquote :: proc(s: string) -> string {
	if len(s) >= 2 && s[0] == '"' && s[len(s) - 1] == '"' {
		return unescape(s[1:len(s) - 1])
	}
	return s
}

// unescape handles the two sequences an exercise needs: a newline and a quote.
// JSON already decoded one level; this is the level inside the expression.
unescape :: proc(s: string) -> string {
	if !strings.contains(s, "\\") {
		return s
	}
	b := strings.builder_make(context.temp_allocator)
	i := 0
	for i < len(s) {
		if s[i] == '\\' && i + 1 < len(s) {
			switch s[i + 1] {
			case 'n':
				strings.write_byte(&b, '\n')
				i += 2
				continue
			case 't':
				strings.write_byte(&b, '\t')
				i += 2
				continue
			case '"':
				strings.write_byte(&b, '"')
				i += 2
				continue
			}
		}
		strings.write_byte(&b, s[i])
		i += 1
	}
	return strings.to_string(b)
}
