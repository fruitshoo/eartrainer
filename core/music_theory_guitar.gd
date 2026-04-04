class_name MusicTheoryGuitar
extends RefCounted

static func get_fret_position(midi_note: int, string_index: int) -> int:
	return midi_note - MusicTheory.OPEN_STRING_MIDI[string_index]

static func get_voicing_key(string_index: int) -> String:
	match string_index:
		0:
			return "6th_string"
		1:
			return "5th_string"
		2:
			return "4th_string"
		_:
			return "6th_string"

static func has_voicing(chord_type: String, string_index: int) -> bool:
	var voicing_key = get_voicing_key(string_index)
	var shapes = MusicTheory.VOICING_SHAPES.get(voicing_key, {})
	return shapes.has(chord_type)

static func get_tab_string(root: int, chord_type: String, string_index: int) -> String:
	var voicing_key = get_voicing_key(string_index)
	var shapes = MusicTheory.VOICING_SHAPES.get(voicing_key, {}).get(chord_type, [])

	if shapes.is_empty():
		return "x-x-x-x-x-x"

	var tabs = ["x", "x", "x", "x", "x", "x"]
	var root_fret = get_fret_position(root, string_index)

	for offset in shapes:
		var target_string_idx = string_index + offset[0]
		var target_fret = root_fret + offset[1]
		if target_string_idx >= 0 and target_string_idx < 6:
			tabs[target_string_idx] = str(target_fret)

	return "".join(tabs)

static func get_preferred_quiz_anchor(key_root: int) -> Dictionary:
	var root_index = key_root % 12

	match root_index:
		2:
			return {"string": 1, "fret": 5}
		4:
			return {"string": 1, "fret": 7}
		9:
			return {"string": 0, "fret": 5}

	var preferred_strings = [0, 1]
	for string_idx in preferred_strings:
		var open_note = MusicTheory.OPEN_STRING_MIDI[string_idx]
		var fret = (root_index - (open_note % 12)) % 12
		if fret < 0:
			fret += 12
		if fret < 3:
			fret += 12
		if fret >= 3 and fret <= 10:
			return {"string": string_idx, "fret": fret}

	var fallback_fret = (root_index - (MusicTheory.OPEN_STRING_MIDI[0] % 12)) % 12
	if fallback_fret < 0:
		fallback_fret += 12
	return {"string": 0, "fret": fallback_fret}
