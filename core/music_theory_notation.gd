class_name MusicTheoryNotation
extends RefCounted

static func get_interval(midi_note: int, root: int) -> int:
	var interval := (midi_note - root) % 12
	return interval + 12 if interval < 0 else interval

static func should_use_flats(key_root: int, mode: int) -> bool:
	var root_index := key_root % 12
	if mode == MusicTheory.ScaleMode.MAJOR:
		return root_index in [1, 3, 5, 8, 10]
	else:
		return root_index in [0, 2, 3, 5, 7, 10]

static func get_note_name(midi_note: int, use_flats: bool = false) -> String:
	var index := midi_note % 12
	if use_flats:
		return MusicTheory.NOTE_NAMES_FLAT[index]
	return MusicTheory.NOTE_NAMES_SHARP[index]

static func get_doremi_name(relative_note: int, use_flats: bool = false) -> String:
	var index := relative_note % 12
	if index < 0:
		index += 12

	if use_flats:
		return MusicTheory.NOTE_NAMES_DOREMI_FLAT[index]
	return MusicTheory.NOTE_NAMES_DOREMI_SHARP[index]

static func get_degree_number_name(midi_note: int, key_root: int) -> String:
	var interval := get_interval(midi_note, key_root)
	return MusicTheory.DEGREE_NUMBERS.get(interval, "?")

static func is_in_scale(midi_note: int, key_root: int, mode: int) -> bool:
	if mode == -1 or not mode in MusicTheory.SCALE_DATA:
		return false

	var interval := get_interval(midi_note, key_root)
	return interval in MusicTheory.SCALE_DATA[mode]["intervals"]

static func get_visual_tier(midi_note: int, chord_root: int, chord_type: String, key_root: int, mode: int) -> int:
	var chord_interval := get_interval(midi_note, chord_root)

	if chord_interval == 0:
		return 1
	if chord_interval in MusicTheory.CHORD_INTERVALS.get(chord_type, []):
		return 2
	if is_in_scale(midi_note, key_root, mode):
		return 3
	return 4

static func get_degree_numeral(chord_root: int, chord_type: String, key_root: int) -> String:
	var interval := get_interval(chord_root, key_root)
	const NUMERALS = ["I", "♭II", "II", "♭III", "III", "IV", "♯IV", "V", "♭VI", "VI", "♭VII", "VII"]
	var numeral: String = NUMERALS[interval]

	if chord_type.begins_with("m") or chord_type.begins_with("dim") or chord_type == "°":
		numeral = numeral.to_lower()

	return numeral + chord_type

static func get_degree_label(chord_root: int, key_root: int, mode: int, chord_type: String = "") -> String:
	var interval := get_interval(chord_root, key_root)
	var label: String = MusicTheory.DEGREE_LABELS[mode].get(interval, "?")
	var is_minor_like: bool = chord_type.begins_with("m") and not chord_type.begins_with("M")
	var is_dim_like: bool = chord_type.begins_with("dim") or chord_type == "°"
	if is_minor_like or is_dim_like:
		label = label.to_lower()
	return label
