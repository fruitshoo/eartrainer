# chord_quiz_handler.gd
extends BaseQuizHandler
class_name ChordQuizHandler

var chord_target_type: String = ""
var found_intervals: Array = []
var is_location_mode: bool = false
var current_inversion: int = 0
var target_degree_idx: int = -1
var _last_degree_idx: int = -1
var _last_root_note: int = -1

# [New] Guitar Form (Voicing) Mode
var _target_positions: Array = [] # [{"string": int, "fret": int, "midi": int}, ...]
var _found_positions: Array = [] # Indices into _target_positions that have been found
var _voicing_root_string: int = -1

# [Fix #3] Normalize chord type names for ChordQuizData lookup
static func _normalize_type(type: String) -> String:
	if type == "maj7": return "M7"
	elif type == "min7": return "m7"
	elif type == "dom7": return "7"
	return type

func start_quiz() -> void:
	manager._stop_playback()
	manager._auto_hide_visuals()
	
	# [New] Degree-based selection: always diatonic
	var degrees = manager.active_degrees
	if degrees.is_empty(): degrees = [0, 1, 2, 3, 4, 5, 6]
	
	# Pick random degree, avoiding duplicate
	var degree_idx = degrees.pick_random()
	if degrees.size() > 1:
		while degree_idx == _last_degree_idx:
			degree_idx = degrees.pick_random()
	
	var chord_data := MusicTheory.get_chord_from_degree(GameManager.current_mode, degree_idx)
	if chord_data.is_empty():
		push_warning("[ChordQuizHandler] get_chord_from_degree returned empty for degree %d" % degree_idx)
		return
	
	var interval = chord_data[0]
	var raw_type = chord_data[1]
	
	# Simplify to triad if the exact 7th type isn't in ChordQuizData
	var final_type = raw_type
	if ChordQuizData.get_chord_intervals(_normalize_type(raw_type)).is_empty():
		# Fallback to triad
		if "maj" in raw_type: final_type = "maj"
		elif "min" in raw_type or "m" in raw_type: final_type = "min"
		else: final_type = "maj"
	
	var base_key = GameManager.current_key
	var root_note = 48 + base_key + interval
	while root_note > 64: root_note -= 12
	
	chord_target_type = final_type
	target_degree_idx = degree_idx
	_last_degree_idx = degree_idx
	_last_root_note = root_note
	
	# Sync back to manager for playback
	manager.chord_target_type = chord_target_type
	manager.interval_root_note = root_note
	
	# Handle Location Mode
	is_location_mode = (manager.current_quiz_type == manager.QuizType.CHORD_LOCATION)
	
	# [New] Guitar Form (Voicing) Mode: compute target positions
	_target_positions = []
	_found_positions = []
	_voicing_root_string = -1
	
	if manager.chord_quiz_use_voicing:
		_setup_voicing_targets(root_note, chord_target_type)
		# Update root_note to match actual voicing position (may have transposed)
		if not _target_positions.is_empty():
			manager.interval_root_note = _target_positions[0]["midi"]
	
	# Determine Inversion
	var available_invs = manager.active_inversions
	if available_invs.is_empty(): available_invs = [0]
	current_inversion = available_invs.pick_random()
	
	# Calculate Guide Note (Bass Note)
	var guide_interval = 0
	if not manager.chord_quiz_use_voicing and current_inversion > 0:
		var raw_intervals = ChordQuizData.get_chord_intervals(_normalize_type(chord_target_type)).duplicate()
		raw_intervals.sort()
		if current_inversion < raw_intervals.size():
			guide_interval = raw_intervals[current_inversion]
	
	var guide_note = root_note + guide_interval
	
	# Voicing mode: highlight only the voicing root position (deferred to avoid settings_changed race)
	if manager.chord_quiz_use_voicing and not _target_positions.is_empty():
		var root_pos = _target_positions[0]
		manager.call_deferred("_clear_markers")
		manager.call_deferred("_highlight_tile", root_pos["string"], root_pos["fret"], Color.WHITE, 2.0)
	else:
		manager.call_deferred("highlight_root_positions", guide_note)
	found_intervals = []
	
	var chord_data_for_label = MusicTheory.get_chord_from_degree(GameManager.current_mode, target_degree_idx)
	var roman_label = chord_data_for_label[2] if not chord_data_for_label.is_empty() else "?"
	
	var mode_str = "Voicing" if manager.chord_quiz_use_voicing else ("Location" if is_location_mode else "Quality")
	print("[ChordQuizHandler] Chord Quiz (%s): degree=%s type=%s root=%d positions=%d" % [
		mode_str, roman_label, chord_target_type, root_note, _target_positions.size()
	])
	
	# Play
	manager._play_quiz_sound(manager.QuizType.CHORD_QUALITY)
	
	manager.quiz_started.emit({
		"type": "chord_location" if is_location_mode else "chord",
		"target": chord_target_type,
		"degree": target_degree_idx,
		"degree_label": roman_label,
		"voicing": manager.chord_quiz_use_voicing
	})

func on_tile_clicked(note: int, _string_idx: int) -> void:
	if manager._is_processing_correct_answer: return
	
	# [New] Guitar Form Mode: match by exact string+fret position
	if manager.chord_quiz_use_voicing and not _target_positions.is_empty():
		_on_voicing_tile_clicked(note, _string_idx)
		return
	
	# Theory Mode: match by interval (any octave)
	var target_root = manager.interval_root_note
	var lookup_type = _normalize_type(chord_target_type)
	var target_intervals = ChordQuizData.get_chord_intervals(lookup_type)
	
	var clicked_interval = (note - target_root) % 12
	if clicked_interval < 0: clicked_interval += 12
	
	if clicked_interval in target_intervals:
		if not clicked_interval in found_intervals:
			found_intervals.append(clicked_interval)
			manager.highlight_found_tone(_string_idx, (note - AudioEngine.OPEN_STRING_MIDI[_string_idx]))
			
			manager.quiz_answered.emit({
				"correct": true, "partial": true,
				"found_count": found_intervals.size(),
				"total_count": target_intervals.size()
			})
			
			if found_intervals.size() >= target_intervals.size():
				_on_all_tones_found()
	else:
		manager.quiz_answered.emit({"correct": false})

func _on_all_tones_found():
	manager._is_processing_correct_answer = true
	print("[ChordQuizHandler] All chord tones found!")
	_play_sfx("correct")
	
	manager.quiz_answered.emit({"correct": true, "chord_type": chord_target_type})
	
	var my_id = manager._current_playback_id
	await manager.get_tree().create_timer(1.2).timeout
	
	if manager._current_playback_id != my_id: return
	# [Fix #1] Allow auto-advance in both CHORD_QUALITY and CHORD_LOCATION (Hybrid Mode)
	if manager.current_quiz_type != manager.QuizType.CHORD_LOCATION and manager.current_quiz_type != manager.QuizType.CHORD_QUALITY: return
	
	start_quiz()

func check_answer(input: Variant) -> void:
	var start_type = str(input)
	if manager._is_processing_correct_answer: return
	
	var is_correct = (start_type == chord_target_type)
	
	if is_correct:
		manager._is_processing_correct_answer = true
		print("[ChordQuizHandler] Correct Chord!")
		_play_sfx("correct")
		
		manager.quiz_answered.emit({"correct": true, "chord_type": chord_target_type})
		
		var my_id = manager._current_playback_id
		await manager.get_tree().create_timer(1.2).timeout
		
		if manager._current_playback_id != my_id: return
		if manager.current_quiz_type != manager.QuizType.CHORD_QUALITY: return
		
		start_quiz()
	else:
		print("[ChordQuizHandler] Wrong Chord.")
		_play_sfx("wrong")
		
		# Replay
		manager._play_quiz_sound(manager.QuizType.CHORD_QUALITY)
		manager.quiz_answered.emit({"correct": false})

# ============================================================
# GUITAR FORM (VOICING) HELPERS
# ============================================================
func _setup_voicing_targets(root_note: int, type: String) -> void:
	var lookup = type
	if type == "maj": lookup = "M"
	if type == "min": lookup = "m"
	
	const MAX_FRET := 12 # Keep all positions within this fret
	
	# Find available root strings where ALL shape positions fit within MAX_FRET
	var available: Array = [] # [{string: int, root: int}]
	for attempt_root in [root_note, root_note - 12]: # Try current octave, then one lower
		for s in [0, 1, 2]: # 6th, 5th, 4th string
			var voicing_key = MusicTheory.get_voicing_key(s)
			var shapes = MusicTheory.VOICING_SHAPES.get(voicing_key, {})
			if not shapes.has(lookup): continue
			
			var root_fret = MusicTheory.get_fret_position(attempt_root, s)
			if root_fret < 0: continue
			
			# Check that ALL shape positions fit within range
			var shape = shapes[lookup]
			var max_shape_fret = root_fret
			for offset in shape:
				var f = root_fret + offset[1]
				if f > max_shape_fret: max_shape_fret = f
			
			if max_shape_fret <= MAX_FRET:
				available.append({"string": s, "root": attempt_root})
	
	if available.is_empty():
		print("[ChordQuizHandler] No playable voicing for type: %s root: %d" % [type, root_note])
		return
	
	var pick = available.pick_random()
	_voicing_root_string = pick["string"]
	var actual_root = pick["root"]
	var voicing_key = MusicTheory.get_voicing_key(_voicing_root_string)
	var shape = MusicTheory.VOICING_SHAPES[voicing_key][lookup]
	
	var root_fret = MusicTheory.get_fret_position(actual_root, _voicing_root_string)
	
	_target_positions = []
	for offset in shape:
		var target_string = _voicing_root_string + offset[0]
		var target_fret = root_fret + offset[1]
		if target_string >= 0 and target_string < 6 and target_fret >= 0:
			var midi = AudioEngine.OPEN_STRING_MIDI[target_string] + target_fret
			_target_positions.append({
				"string": target_string,
				"fret": target_fret,
				"midi": midi
			})
	
	print("[ChordQuizHandler] Voicing targets (%s root string %d, fret %d): %s" % [
		lookup, _voicing_root_string, root_fret, _target_positions
	])

func _on_voicing_tile_clicked(note: int, string_idx: int) -> void:
	var fret = note - AudioEngine.OPEN_STRING_MIDI[string_idx]
	print("[ChordQuiz-Voicing] Clicked: string=%d fret=%d note=%d" % [string_idx, fret, note])
	print("[ChordQuiz-Voicing] Targets: %s" % str(_target_positions))
	print("[ChordQuiz-Voicing] Already found: %s" % str(_found_positions))
	
	# Check if this position matches any unfound target
	for i in range(_target_positions.size()):
		if i in _found_positions: continue
		var pos = _target_positions[i]
		if pos["string"] == string_idx and pos["fret"] == fret:
			_found_positions.append(i)
			print("[ChordQuiz-Voicing] MATCH! Found position %d (%d/%d)" % [i, _found_positions.size(), _target_positions.size()])
			manager.highlight_found_tone(string_idx, fret)
			
			manager.quiz_answered.emit({
				"correct": true, "partial": true,
				"found_count": _found_positions.size(),
				"total_count": _target_positions.size()
			})
			
			if _found_positions.size() >= _target_positions.size():
				_on_all_tones_found()
			return
	
	# Wrong position
	print("[ChordQuiz-Voicing] WRONG position")
	manager.quiz_answered.emit({"correct": false})

# ============================================================
# PLAYBACK
# ============================================================
func _play_chord_structure(root: int, type: String):
	# [New] Guitar Form Mode: play from voicing positions
	if manager.chord_quiz_use_voicing and not _target_positions.is_empty():
		_play_voicing_structure()
		return
	
	# Theory Mode: play from intervals
	var intervals = ChordQuizData.get_chord_intervals(_normalize_type(type)).duplicate()
	if intervals.is_empty(): return
	
	var inversion = current_inversion
	for i in range(inversion):
		if intervals.size() > 0:
			var low_note = intervals.pop_front()
			intervals.push_back(low_note + 12)
	
	intervals.sort()
	
	var avail_dirs = manager.active_directions
	if avail_dirs.is_empty(): avail_dirs = [2]
	var direction = avail_dirs.pick_random()
	
	var playback_notes = []
	for interval in intervals:
		playback_notes.append(root + interval)
		
	var delay_step = 0.4
	
	match direction:
		1: playback_notes.reverse()
		2: delay_step = 0.05
			
	var my_id = manager._current_playback_id
	for i in range(playback_notes.size()):
		var p_note = playback_notes[i]
		var delay = i * delay_step
		
		manager.get_tree().create_timer(delay).timeout.connect(func():
			if manager._current_playback_id != my_id: return
			AudioEngine.play_note(p_note)
		)

func _play_voicing_structure() -> void:
	var avail_dirs = manager.active_directions
	if avail_dirs.is_empty(): avail_dirs = [2]
	var direction = avail_dirs.pick_random()
	
	# Sort by string index (low to high = 6th to 1st)
	var sorted_positions = _target_positions.duplicate()
	sorted_positions.sort_custom(func(a, b): return a["string"] < b["string"])
	
	var delay_step = 0.4
	match direction:
		1: sorted_positions.reverse() # Down = high string first
		2: delay_step = 0.05 # Strum
	
	var my_id = manager._current_playback_id
	for i in range(sorted_positions.size()):
		var pos = sorted_positions[i]
		var delay = i * delay_step
		
		manager.get_tree().create_timer(delay).timeout.connect(func():
			if manager._current_playback_id != my_id: return
			AudioEngine.play_note(pos["midi"], pos["string"])
		)
