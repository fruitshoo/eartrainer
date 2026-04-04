class_name GameManagerTheory
extends RefCounted

var manager

func _init(p_manager) -> void:
	manager = p_manager

func set_scale_override(key: int, mode: int, use_flats: int = -1) -> void:
	if manager.override_key != key or manager.override_mode != mode or manager.override_use_flats != use_flats:
		manager.override_key = key
		manager.override_mode = mode
		manager.override_use_flats = use_flats

func clear_scale_override() -> void:
	if manager.override_key != -1 or manager.override_mode != -1 or manager.override_use_flats != -1:
		manager.override_key = -1
		manager.override_mode = -1
		manager.override_use_flats = -1

func get_tile_tier(midi_note: int) -> int:
	var target_key = manager.current_key
	var target_mode = manager.current_mode
	if manager.override_key != -1:
		target_key = manager.override_key
		target_mode = manager.override_mode

	return MusicTheory.get_visual_tier(
		midi_note,
		manager.current_chord_root,
		manager.current_chord_type,
		target_key,
		target_mode
	)

func get_current_chord_interval(midi_note: int) -> int:
	var diff = (midi_note - manager.current_chord_root) % 12
	if diff < 0:
		diff += 12
	return diff

func get_note_label(midi_note: int) -> String:
	var base_key: int = manager.current_key
	var base_mode: int = manager.current_mode
	var target_key: int = base_key
	var target_mode: int = base_mode
	if manager.override_key != -1 and manager.override_mode != -1:
		target_key = manager.override_key
		target_mode = manager.override_mode

	var use_flats: bool = (manager.override_use_flats == 1) if manager.override_use_flats != -1 else MusicTheory.should_use_flats(target_key, target_mode)

	match manager.current_notation_mode:
		manager.NotationMode.CDE:
			return MusicTheory.get_note_name(midi_note, use_flats)
		manager.NotationMode.DOREMI:
			var relative: int = (midi_note - base_key) % 12
			if relative < 0:
				relative += 12
			var movable_use_flats: bool = MusicTheory.should_use_flats(base_key, base_mode)
			return MusicTheory.get_doremi_name(relative, movable_use_flats)
		manager.NotationMode.DEGREE:
			return MusicTheory.get_degree_number_name(midi_note, base_key)

	return ""

func is_in_scale(midi_note: int) -> bool:
	var target_key: int = manager.current_key
	var target_mode: int = manager.current_mode
	if manager.override_key != -1 and manager.override_mode != -1:
		target_key = manager.override_key
		target_mode = manager.override_mode

	return MusicTheory.is_in_scale(midi_note, target_key, target_mode)

func toggle_mode() -> void:
	match manager.current_mode:
		MusicTheory.ScaleMode.MAJOR:
			manager.current_mode = MusicTheory.ScaleMode.MINOR
		MusicTheory.ScaleMode.MINOR:
			manager.current_mode = MusicTheory.ScaleMode.MAJOR
		MusicTheory.ScaleMode.MAJOR_PENTATONIC:
			manager.current_mode = MusicTheory.ScaleMode.MINOR_PENTATONIC
		MusicTheory.ScaleMode.MINOR_PENTATONIC:
			manager.current_mode = MusicTheory.ScaleMode.MAJOR_PENTATONIC
		_:
			manager.current_mode = MusicTheory.ScaleMode.MAJOR

	manager.settings_changed.emit()

func apply_diatonic_chord(keycode: int) -> void:
	var data := MusicTheory.get_chord_from_keycode(manager.current_mode, keycode)
	if data.is_empty():
		return

	manager.current_chord_root = (manager.current_key + data[0]) % 12
	manager.current_chord_type = data[1]
	manager.current_degree = data[2]
	manager.settings_changed.emit()
