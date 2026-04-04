class_name QuizManagerVisuals
extends RefCounted

var manager
var active_markers: Array = []

func _init(p_manager) -> void:
	manager = p_manager

func find_valid_pos_for_note(midi_note: int, preferred_fret: int = -1) -> Dictionary:
	if preferred_fret == -1:
		if manager.interval_fixed_anchor:
			var anchor = MusicTheory.get_preferred_quiz_anchor(GameManager.current_key)
			if not anchor.is_empty():
				preferred_fret = anchor.fret
			elif manager._current_root_fret != -1:
				preferred_fret = manager._current_root_fret
			else:
				preferred_fret = GameManager.player_fret
		else:
			preferred_fret = GameManager.player_fret

	var candidates = []
	var open_notes = AudioEngine.OPEN_STRING_MIDI

	for s_idx in range(6):
		var fret = midi_note - open_notes[s_idx]
		if fret >= 0 and GameManager.find_tile(s_idx, fret):
			var dist = abs(fret - preferred_fret)
			candidates.append({"valid": true, "string": s_idx, "fret": fret, "dist": dist})

	if candidates.is_empty():
		return {"valid": false, "string": -1, "fret": -1}

	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	return candidates[0]

func find_all_positions_for_note(midi_note: int, min_string_idx: int = 0) -> Array:
	var results = []
	var open_notes = AudioEngine.OPEN_STRING_MIDI
	for s_idx in range(min_string_idx, 6):
		var fret = midi_note - open_notes[s_idx]
		if fret >= 0 and GameManager.find_tile(s_idx, fret):
			results.append({"string": s_idx, "fret": fret})
	return results

func find_closest_root_for_pitch_class(pitch_class: int, anchor_fret: int = -1) -> Dictionary:
	if anchor_fret == -1:
		if manager.interval_fixed_anchor:
			var anchor = MusicTheory.get_preferred_quiz_anchor(GameManager.current_key)
			if not anchor.is_empty():
				anchor_fret = anchor.fret
			elif manager._current_root_fret != -1:
				anchor_fret = manager._current_root_fret
			else:
				anchor_fret = GameManager.player_fret
		else:
			anchor_fret = GameManager.player_fret

	var candidates = []
	var open_notes = AudioEngine.OPEN_STRING_MIDI

	for s_idx in range(3):
		var open_note = open_notes[s_idx]
		var fret = (pitch_class - (open_note % 12)) % 12
		if fret < 0:
			fret += 12

		for f in [fret, fret + 12]:
			if f >= 0 and f <= 19 and GameManager.find_tile(s_idx, f):
				var penalty = 0.0
				if s_idx == 2:
					penalty = 4.0
				candidates.append({
					"valid": true,
					"string": s_idx,
					"fret": f,
					"midi_note": open_note + f,
					"dist": abs(f - anchor_fret) + penalty
				})

	if candidates.is_empty():
		return {"valid": false}

	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	return candidates[0]

func highlight_root_positions(midi_note: int, clear_previous: bool = true) -> void:
	print("[QuizManager] highlight_root_positions called for Note: %d (Clear: %s)" % [midi_note, clear_previous])
	if clear_previous:
		clear_markers()

	var positions = find_all_positions_for_note(midi_note, 0)
	var highlight_color = Color(0.9, 0.7, 0.3)
	for pos in positions:
		highlight_tile(pos.string, pos.fret, highlight_color, 0.8)

func highlight_tile(string_idx: int, fret_idx: int, color: Color, energy: float = 1.0) -> void:
	var tile = GameManager.find_tile(string_idx, fret_idx)
	if tile and tile.has_method("set_marker"):
		tile.set_marker(color, energy)
		if not tile in active_markers:
			active_markers.append(tile)

func clear_markers() -> void:
	for tile in active_markers:
		if is_instance_valid(tile) and tile.has_method("clear_marker"):
			tile.clear_marker()
	active_markers.clear()

func highlight_found_tone(string_idx: int, fret_idx: int) -> void:
	highlight_tile(string_idx, fret_idx, Color.SPRING_GREEN, 2.0)

func highlight_degree(degree_idx: int, clear_previous: bool = true) -> void:
	var scale_intervals = MusicTheory.SCALE_INTERVALS[GameManager.current_mode]
	if degree_idx >= scale_intervals.size():
		return

	var interval = scale_intervals[degree_idx]
	var root_pc = (GameManager.current_key + interval) % 12

	if clear_previous:
		clear_markers()

	var best_pos = find_closest_root_for_pitch_class(root_pc)
	if best_pos.valid:
		var highlight_color = Color(0.9, 0.7, 0.3)
		highlight_tile(best_pos.string, best_pos.fret, highlight_color, 0.8)
		print("[QuizManager] highlight_degree(%d) -> PC: %d at Str %d Fret %d" % [degree_idx, root_pc, best_pos.string, best_pos.fret])

func play_note_with_blink(note: int, duration: float = 0.3, force_visual: bool = true) -> void:
	AudioEngine.play_note(note)

	var should_show = force_visual or GameManager.show_target_visual
	if not should_show:
		return

	var string_idx = -1
	for tile in active_markers:
		if is_instance_valid(tile) and tile.midi_note == note:
			string_idx = tile.string_index
			break

	if string_idx == -1:
		var pos = find_valid_pos_for_note(note, manager._current_root_fret)
		string_idx = pos.string if pos.valid else 0

	EventBus.visual_note_on.emit(note, string_idx)

	var my_id = manager._current_playback_id
	manager.get_tree().create_timer(duration).timeout.connect(func():
		if manager._current_playback_id != my_id:
			return
		EventBus.visual_note_off.emit(note, string_idx)
	)
