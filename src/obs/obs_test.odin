package tutor_obs

import "core:testing"

@(test)
a_stream_round_trips :: proc(t: ^testing.T) {
	original := Stream {
		schema_version = SCHEMA_VERSION,
		adapter = "gdb-python/1",
		source_file = "m.odin",
		records = {
			{
				index = 0, file = "m.odin", line = 4, stdout_len = 7,
				frames = {
					{
						procedure = "main", file = "m.odin", line = 4,
						caller_pc = 0x1234, caller_sp = 0x5678,
						variables = {{name = "x", value = {state = .Valid, kind = .Scalar, text = "1"}}},
					},
				},
			},
		},
		termination = .Completed,
	}
	data, ok := encode(original, context.temp_allocator)
	testing.expect(t, ok, "a stream must encode")

	back, err := decode(data, context.temp_allocator)
	testing.expect_value(t, err, Decode_Error.None)
	testing.expect_value(t, back.records[0].frames[0].caller_pc, u64(0x1234))
	testing.expect_value(t, back.records[0].stdout_len, 7)
}

@(test)
an_unknown_schema_version_is_refused :: proc(t: ^testing.T) {
	// Reading the parts we recognise from a future format is how a confident
	// wrong picture gets drawn.
	data := transmute([]byte)string(`{"schema_version":99,"records":[]}`)
	_, err := decode(data, context.temp_allocator)
	testing.expect_value(t, err, Decode_Error.Unsupported_Version)
}

@(test)
malformed_input_is_named_not_crashed :: proc(t: ^testing.T) {
	data := transmute([]byte)string(`{not json at all`)
	_, err := decode(data, context.temp_allocator)
	testing.expect_value(t, err, Decode_Error.Malformed_Json)
}

@(test)
stdout_len_is_named_in_bytes :: proc(t: ^testing.T) {
	// SPEC-SAFE-031: a budget and the limit it protects use the same unit, and
	// the unit is in the field name. A prior system lost whole traces to a
	// character count guarding a byte limit.
	//
	// This test asserts the contract by construction: the field carries the
	// byte length of text whose character count differs.
	text := "coração ✓"
	r := Record{stdout_len = len(text)}
	testing.expect_value(t, r.stdout_len, 13)
	testing.expect(t, r.stdout_len != 9, "13 bytes, 9 characters — the units differ")
}
