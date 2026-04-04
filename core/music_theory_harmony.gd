class_name MusicTheoryHarmony
extends RefCounted

static func get_scale_intervals(mode: int) -> Array:
	return MusicTheory.SCALE_DATA[mode]["intervals"]

static func get_diatonic_type(midi_note: int, key_root: int, mode: int) -> String:
	var chord_mode = mode
	var parent_mode = MusicTheory.SCALE_DATA[mode].get("parent_mode")
	if parent_mode != null:
		chord_mode = parent_mode

	var intervals = MusicTheory.SCALE_DATA[chord_mode]["intervals"]
	var target_interval := MusicTheoryNotation.get_interval(midi_note, key_root)
	var degree_idx = intervals.find(target_interval)
	if degree_idx == -1:
		return "M7"

	var count = intervals.size()
	if count < 5:
		return "M7"

	var third_idx = (degree_idx + 2) % count
	var fifth_idx = (degree_idx + 4) % count
	var seventh_idx = (degree_idx + 6) % count

	var root_val = intervals[degree_idx]
	var third_val = intervals[third_idx]
	var fifth_val = intervals[fifth_idx]
	var seventh_val = intervals[seventh_idx]

	if third_idx < degree_idx:
		third_val += 12
	if fifth_idx < degree_idx:
		fifth_val += 12
	if seventh_idx < degree_idx:
		seventh_val += 12

	var dist_third = third_val - root_val
	var dist_fifth = fifth_val - root_val
	var dist_seventh = seventh_val - root_val

	if dist_third == 4:
		if dist_fifth == 7:
			if dist_seventh == 11:
				return "M7"
			else:
				return "7"
		elif dist_fifth == 8:
			return "aug"
	elif dist_third == 3:
		if dist_fifth == 7:
			if dist_seventh == 11:
				return "mM7"
			else:
				return "m7"
		elif dist_fifth == 6:
			if dist_seventh == 9:
				return "dim7"
			else:
				return "m7b5"

	return "M7"

static func is_effectively_diatonic_chord(chord_root: int, chord_type: String, key_root: int, mode: int) -> bool:
	if not MusicTheoryNotation.is_in_scale(chord_root, key_root, mode):
		return false
	var expected = get_diatonic_type(chord_root, key_root, mode)
	if chord_type == expected:
		return true
	if chord_type == "5" and expected != "m7b5" and expected != "dim7":
		return true
	return false

static func get_visual_scale_override(chord_root: int, chord_type: String, key_root: int, mode: int) -> Dictionary:
	if is_effectively_diatonic_chord(chord_root, chord_type, key_root, mode):
		return {"use_override": false}

	var parallel_mode := -1
	if mode == MusicTheory.ScaleMode.MAJOR:
		parallel_mode = MusicTheory.ScaleMode.MINOR
	elif mode == MusicTheory.ScaleMode.MINOR:
		parallel_mode = MusicTheory.ScaleMode.MAJOR

	if parallel_mode != -1 and is_effectively_diatonic_chord(chord_root, chord_type, key_root, parallel_mode):
		return {
			"use_override": true,
			"key": key_root,
			"mode": parallel_mode,
			"use_flats": MusicTheoryNotation.should_use_flats(key_root, parallel_mode)
		}

	if chord_type == "7":
		var target_root = (chord_root + 5) % 12
		if MusicTheoryNotation.is_in_scale(target_root, key_root, mode):
			var target_mode = get_display_mode_for_chord_quality(get_diatonic_type(target_root, key_root, mode))
			return {
				"use_override": true,
				"key": target_root,
				"mode": target_mode,
				"use_flats": MusicTheoryNotation.should_use_flats(target_root, target_mode)
			}

	var fallback_mode = get_display_mode_for_chord_quality(chord_type)
	return {
		"use_override": true,
		"key": chord_root % 12,
		"mode": fallback_mode,
		"use_flats": MusicTheoryNotation.should_use_flats(chord_root % 12, fallback_mode)
	}

static func toggle_quality(current_type: String) -> String:
	match current_type:
		"M7":
			return "m7"
		"m7":
			return "M7"
		"7":
			return "m7"
		"m7b5":
			return "m7"
		_:
			return "M7"

static func get_display_mode_for_chord_quality(chord_type: String) -> int:
	if chord_type == "m7b5" or chord_type == "dim7" or chord_type.begins_with("dim"):
		return MusicTheory.ScaleMode.LOCRIAN
	if chord_type == "7" or chord_type == "7sus4":
		return MusicTheory.ScaleMode.MIXOLYDIAN
	if chord_type.begins_with("m") and not chord_type.begins_with("M"):
		return MusicTheory.ScaleMode.MINOR
	return MusicTheory.ScaleMode.MAJOR

static func get_chord_from_degree(mode: int, degree_idx: int) -> Array:
	var chord_mode = mode
	var parent_mode = MusicTheory.SCALE_DATA[mode].get("parent_mode")
	if parent_mode != null:
		chord_mode = parent_mode

	var intervals = MusicTheory.SCALE_DATA[chord_mode]["intervals"]
	if degree_idx < 0 or degree_idx >= intervals.size():
		return []

	var interval = intervals[degree_idx]
	var chord_type = get_diatonic_type(interval, 0, chord_mode)
	var roman = MusicTheory.DEGREE_LABELS.get(chord_mode, MusicTheory.DEGREE_LABELS[MusicTheory.ScaleMode.MAJOR]).get(interval, "?")

	return [interval, chord_type, roman]

static func get_chord_from_keycode(mode: int, keycode: int) -> Array:
	var degree_idx = -1
	match keycode:
		KEY_1:
			degree_idx = 0
		KEY_2:
			degree_idx = 1
		KEY_3:
			degree_idx = 2
		KEY_4:
			degree_idx = 3
		KEY_5:
			degree_idx = 4
		KEY_6:
			degree_idx = 5
		KEY_7:
			degree_idx = 6

	if degree_idx == -1:
		return []
	return get_chord_from_degree(mode, degree_idx)
