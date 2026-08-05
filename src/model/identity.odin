// Package tutor_model turns observation records into a trace.
//
// Everything subtle lives here: identity, shared storage, epochs, and the
// delta encoding. None of it needs a debugger, so all of it is tested in
// milliseconds. See docs/decisions/ADR-003.
package tutor_model

import "core:fmt"

// Id is a logical identity. It is a dense counter over a deterministic
// traversal, never an address. See SPEC-MEM-001, REQ-MEM-001.
Id :: distinct int

NO_ID :: Id(0)

// Entity_Kind separates the three things an address can be. Collapsing them is
// how a sub-slice inherits its parent's length. See MEMORY-MODEL.md §3.
Entity_Kind :: enum {
	// Storage is a region of memory that holds elements.
	Storage,
	// View is a window onto a storage: a slice, a string.
	View,
	// Object is a thing with fields: a struct, a pointer target.
	Object,
}

// Key identifies an entity across steps.
//
// `location` is included because two empty slices are byte-identical —
// both are {data: 0x0, len: 0} — and only the address of the variable that
// holds each one separates them. Measured 2026-08-05. See SPEC-MEM-006.
Key :: struct {
	kind:      Entity_Kind,
	// address of the storage, or 0 when there is none.
	address:   u64,
	// location of the holder, which distinguishes two empty views.
	location:  u64,
	// length distinguishes two views over one storage. See SPEC-MEM-005.
	length:    int,
	type_name: string,
	// epoch separates two storages that reused one address.
	// See SPEC-MEM-040 and ADR-011.
	epoch:     int,
}

// Registry assigns identities and remembers them across steps.
Registry :: struct {
	assigned: map[Key]Id,
	// epochs tracks the current epoch per (address, type), so that a reused
	// address can produce a new identity.
	epochs:   map[Epoch_Key]int,
	// last_seen records the step index at which an address was last in the
	// reachable set.
	last_seen: map[Epoch_Key]int,
	// last_type records the type last seen at an address. A different type at
	// one address is positive evidence: the bytes there are a different thing
	// now. See SPEC-MEM-041 rule 1.
	last_type: map[u64]string,
	next:     Id,
}

Epoch_Key :: struct {
	address:   u64,
	type_name: string,
}

registry_init :: proc(r: ^Registry, allocator := context.allocator) {
	r.assigned = make(map[Key]Id, allocator)
	r.epochs = make(map[Epoch_Key]int, allocator)
	r.last_seen = make(map[Epoch_Key]int, allocator)
	r.last_type = make(map[u64]string, allocator)
	r.next = 1
}

registry_destroy :: proc(r: ^Registry) {
	delete(r.assigned)
	delete(r.epochs)
	delete(r.last_seen)
	delete(r.last_type)
}

// identity_for returns the identity of an entity, assigning one if this is
// the first time it has been seen.
//
// It never compares contents. Two objects with equal contents and different
// storage get different identities. See SPEC-MEM-004, REQ-MEM-006.
identity_for :: proc(r: ^Registry, key: Key) -> Id {
	if id, found := r.assigned[key]; found {
		return id
	}
	id := r.next
	r.next += 1
	r.assigned[key] = id
	return id
}

// epoch_for returns the current epoch for an address of a given type.
epoch_for :: proc(r: ^Registry, address: u64, type_name: string) -> int {
	if address == 0 {
		return 0
	}
	return r.epochs[Epoch_Key{address, type_name}]
}

// note_seen records that an address was in the reachable set at `step`.
note_seen :: proc(r: ^Registry, address: u64, type_name: string, step: int) {
	if address == 0 {
		return
	}
	r.last_seen[Epoch_Key{address, type_name}] = step
}

// advance_epoch_on_absence implements SPEC-MEM-041 rule 2, with the guard
// that ADR-011 requires.
//
// An address that disappeared and came back is *usually* a new allocation.
// But the reachable set is a property of our traversal, not of the program:
// a budget can hide a living object. So absence counts as evidence only when
// every step it was absent for was observed completely.
//
// `step_was_truncated` answers, for each step in between, whether anything was
// cut. If any was, the epoch does not advance and the identity survives.
// A budget must never change an identity. See SPEC-MEM-044.
advance_epoch_on_absence :: proc(
	r: ^Registry,
	address: u64,
	type_name: string,
	step: int,
	step_was_truncated: []bool,
) -> (
	advanced: bool,
) {
	if address == 0 {
		return false
	}
	ek := Epoch_Key{address, type_name}
	seen, found := r.last_seen[ek]
	if !found || seen == step || seen == step - 1 {
		// Never absent. Nothing to decide.
		return false
	}
	for missing in seen + 1 ..< step {
		if missing >= 0 && missing < len(step_was_truncated) && step_was_truncated[missing] {
			// The observation was incomplete. Absence of evidence is not
			// evidence of death.
			return false
		}
	}
	r.epochs[ek] += 1
	return true
}

// advance_epoch_on_free records a death the PROGRAM reported.
//
// This is the one piece of positive evidence the identity model can have, and
// it needs no guard. ADR-011's whole argument is that ABSENCE is unsafe
// evidence, because the reachable set is a property of our traversal and a
// budget can hide a living object. A free event is not absence. The program
// handed the storage back.
//
// Every type at the address advances, because the bytes are dead whatever they
// were. The next allocation there gets a new identity, which is exactly the case
// SPEC-MEM-042 recorded as a known incorrectness in version 1.
advance_epoch_on_free :: proc(r: ^Registry, address: u64) {
	if address == 0 {
		return
	}
	if type_name, found := r.last_type[address]; found {
		r.epochs[Epoch_Key{address, type_name}] += 1
	}
	// Also forget the address, so a later absence is not ALSO counted. One
	// death, one epoch: counting it twice would split a live object in half.
	delete_key(&r.last_type, address)
	delete_key(&r.last_seen, Epoch_Key{address, ""})
}

// advance_epoch_on_type_change implements SPEC-MEM-041 rule 1. A different
// type at one address is positive evidence: the bytes there are a different
// thing now.
advance_epoch_on_type_change :: proc(r: ^Registry, address: u64, old, new: string) {
	if address == 0 || old == new {
		return
	}
	r.epochs[Epoch_Key{address, new}] += 1
}

// Storage_Range is a region of the target that one or more views sit on.
Storage_Range :: struct {
	id:    Id,
	start: u64,
	end:   u64,
	type_name: string,
}

// storage_for returns the identity of the storage a view sits on, grouping
// views whose ranges overlap.
//
// This is what makes a sub-slice a *window* rather than an unrelated object.
// `notas` and `notas[1:]` have different data pointers — measured, eight bytes
// apart — so keying storage by the view's own pointer would give two storages
// and the sharing would never be visible. Overlap is the fact that matters.
//
// Grouping is the only claim made here. The two views keep their own
// identities and their own lengths, because collapsing them is the sub-slice
// bug: a window drawn with its parent's length. See SPEC-MEM-005, REQ-MEM-005.
storage_for :: proc(
	ranges: ^[dynamic]Storage_Range,
	r: ^Registry,
	data: u64,
	length: int,
	elem_size: int,
	type_name: string,
	epoch: int,
) -> Id {
	if data == 0 {
		return NO_ID
	}
	size := elem_size
	if size <= 0 {
		size = 1
	}
	start := data
	end := data + u64(length * size)
	if end == start {
		end = start + 1
	}

	for &existing in ranges {
		if existing.type_name != type_name {
			continue
		}
		if start < existing.end && existing.start < end {
			// Overlapping. Widen the known extent: a later view may reach
			// further than the first one did.
			if start < existing.start {
				existing.start = start
			}
			if end > existing.end {
				existing.end = end
			}
			return existing.id
		}
	}

	id := identity_for(r, Key{kind = .Storage, address = data, type_name = type_name, epoch = epoch})
	append(ranges, Storage_Range{id = id, start = start, end = end, type_name = type_name})
	return id
}

// label renders an identity the way the interface shows it. Labels, not
// arrows: a terminal is a character grid. See ADR-007.
label :: proc(id: Id, allocator := context.allocator) -> string {
	return fmt.aprintf("#%d", int(id), allocator = allocator)
}
