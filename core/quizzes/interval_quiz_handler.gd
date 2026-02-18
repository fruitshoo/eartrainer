# interval_quiz_handler.gd
extends BaseQuizHandler
class_name IntervalQuizHandler

var interval_root_note: int = -1
var interval_target_note: int = -1
var interval_semitones: int = 0
var current_interval_mode: int = 0 # IntervalMode enum in manager
var _last_semitones: int = -1 # [New #6] Prevent consecutive duplicates

func start_quiz() -> void:
	manager._stop_playback()
	manager._clear_markers()
	manager._is_processing_correct_answer = false
	
	manager.current_quiz_type = manager.QuizType.INTERVAL
	
	var active_intervals = manager.active_intervals
	if active_intervals.is_empty():
		print("[IntervalQuizHandler] No intervals selected!")
		return

	# 1. Select Interval (avoid repeating same one)
	if active_intervals.size() > 1:
		var filtered = active_intervals.filter(func(s): return s != _last_semitones)
		interval_semitones = filtered.pick_random()
	else:
		interval_semitones = active_intervals.pick_random()
	_last_semitones = interval_semitones
	
	# 2. Determine Mode
	if manager.active_modes.is_empty():
		current_interval_mode = 0 # ASCENDING
	else:
		current_interval_mode = manager.active_modes.pick_random()
		
	# 3. Harmonic Context (Play Tonic Chord first if enabled)
	if manager.interval_harmonic_context:
		_play_context()
		await manager.get_tree().create_timer(1.0).timeout
	
	# 4. Find Valid Position (Near Player)
	# 4. Find Valid Position (Near Player)
	# [Fix] Don't use player_fret as anchor, as it causes "drifting" up the neck on ascending intervals.
	# Instead, pick a random anchor in lower/mid neck (e.g. fret 2-8)
	var center_fret = randi_range(2, 5)
	# Note: root_fret adds (randi() % 5 - 2) -> -2 to +2. 
	# So random center 2-5 means roots could be 0 to 7. Safe range.
	
	var valid_found = false
	var max_retries = 50 # Increased retries for stricter constraints
	var final_string_idx = -1
	var final_fret_idx = -1
	
	var key_root = GameManager.current_key
	var key_mode = GameManager.current_mode
	
	for i in range(max_retries):
		# [String Constraint Logic]
		# 0=All, 1=Same, 2=Cross
		var constraint = manager.interval_string_constraint
		
		var root_string = randi() % 6
		
		# [Fret Logic]
		# Try to stay near center fret, but explore slightly wider
		var root_fret = center_fret + (randi() % 5 - 2)
		root_fret = clampi(root_fret, 0, 12)
		
		var candidate_root = AudioEngine.OPEN_STRING_MIDI[root_string] + root_fret
		
		# [Diatonic Validation - Step 1]
		# If Diatonic Mode is ON, Root MUST be in scale
		if manager.interval_diatonic_mode:
			if not MusicTheory.is_in_scale(candidate_root, key_root, key_mode):
				continue
		
		var candidate_target = -1
		if current_interval_mode == 1: # DESCENDING
			candidate_target = candidate_root - interval_semitones
		else:
			candidate_target = candidate_root + interval_semitones
			
		if candidate_target < 40 or candidate_target > 88: # Range check
			continue
			
		# [Diatonic Validation - Step 2]
		# If Diatonic Mode is ON, Target MUST ALSO be in scale
		if manager.interval_diatonic_mode:
			if not MusicTheory.is_in_scale(candidate_target, key_root, key_mode):
				continue
		
		var target_pos = _find_target_pos_with_constraint(candidate_target, root_string, root_fret, constraint)
		if not target_pos.valid:
			continue
			
		interval_root_note = candidate_root
		interval_target_note = candidate_target
		final_string_idx = root_string
		final_fret_idx = root_fret
		manager._current_root_fret = final_fret_idx
		
		valid_found = true
		break
			
	if not valid_found:
		print("[IntervalQuizHandler] Using chromatic fallback.")
		# Move fallback logic to manager or specialized method here?
		# For now, let's keep it in handler as it's quiz-specific
		_pick_fallback_question(center_fret)
		var pos = manager._find_valid_pos_for_note(interval_root_note)
		if pos.valid:
			final_string_idx = pos.string
			final_fret_idx = pos.fret
			manager._current_root_fret = final_fret_idx

	# Sync back to manager for playback
	manager.interval_root_note = interval_root_note
	manager.interval_target_note = interval_target_note
	manager.interval_semitones = interval_semitones
	manager.current_interval_mode = current_interval_mode

	# Highlight Root
	manager._highlight_tile(final_string_idx, final_fret_idx, Color.WHITE)
	
	# Play
	replay()
	
	manager.quiz_started.emit({
		"type": "interval",
		"root": interval_root_note,
		"target": interval_target_note,
		"mode": current_interval_mode
	})

func on_tile_clicked(clicked_note: int, string_idx: int) -> void:
	if manager._is_processing_correct_answer: return

	var is_correct = false
	if current_interval_mode == 0: # ASCENDING
		is_correct = (clicked_note == interval_target_note)
	elif current_interval_mode == 1: # DESCENDING
		is_correct = (clicked_note == interval_target_note)
	elif current_interval_mode == 2: # HARMONIC
		# [Fix #2] Use modulo 12 for octave-aware checking
		var clicked_diff = abs(clicked_note - interval_root_note) % 12
		is_correct = (clicked_diff == interval_semitones % 12) and clicked_note != interval_root_note
		
	var fret_idx = MusicTheory.get_fret_position(clicked_note, string_idx)
	var tile = GameManager.find_tile(string_idx, fret_idx)
	
	if is_correct:
		manager._is_processing_correct_answer = true
		_play_sfx("correct")
		
		if tile and tile.has_method("_show_rhythm_feedback"):
			tile.call("_show_rhythm_feedback", {"rating": "Perfect!", "color": Color.WHITE})
		
		# Show both
		var root_pos = manager._find_valid_pos_for_note(interval_root_note, manager._current_root_fret)
		if root_pos.valid:
			manager._highlight_tile(root_pos.string, root_pos.fret, Color.WHITE)
		manager._highlight_tile(string_idx, fret_idx, Color.WHITE)
		
		var reward_duration = manager._play_reward_song(interval_semitones, current_interval_mode)
		manager.quiz_answered.emit({"correct": true, "interval": interval_semitones})
		
		var my_id = manager._current_playback_id
		var wait_time = reward_duration + 1.0 if reward_duration > 0 else 1.0
		
		await manager.get_tree().create_timer(wait_time).timeout
		
		if manager._current_playback_id != my_id: return
		if manager.current_quiz_type != manager.QuizType.INTERVAL: return
		
		start_quiz()
	else:
		_play_sfx("wrong")
		if tile and tile.has_method("_show_rhythm_feedback"):
			tile.call("_show_rhythm_feedback", {"rating": "Try Again", "color": Color.RED})
		manager.quiz_answered.emit({"correct": false})

func _pick_fallback_question(center_fret: int) -> void:
	var root_string = randi() % 6
	var min_fret = max(0, center_fret - 3)
	var max_fret = min(12, center_fret + 3)
	var root_fret = randi_range(min_fret, max_fret)
	
	interval_root_note = AudioEngine.OPEN_STRING_MIDI[root_string] + root_fret
	
	if current_interval_mode == 1: # DESCENDING
		interval_target_note = interval_root_note - interval_semitones
	else:
		interval_target_note = interval_root_note + interval_semitones
		
	# [Fix] Ensure target is also playable within 12 frets on SOME string
	var target_playable = false
	for s in range(6):
		var f = interval_target_note - AudioEngine.OPEN_STRING_MIDI[s]
		if f >= 0 and f <= 12:
			target_playable = true
			break
			
	if not target_playable:
		# Try inverting direction if possible
		if current_interval_mode == 0: # Was Ascending, try Descending
			interval_target_note = interval_root_note - interval_semitones
			current_interval_mode = 1
		else: # Was Descending, try Ascending
			interval_target_note = interval_root_note + interval_semitones
			current_interval_mode = 0
			
	# Safety clamps (MIDI range)
	if interval_target_note < 40:
		interval_target_note = 40;
		interval_root_note = 40 + interval_semitones
	if interval_target_note > 76: # High E 12th fret is 76
		interval_target_note = 76;
		interval_root_note = 76 - interval_semitones

func _play_context() -> void:
	# Plays the tonic chord (Triad) of the current key
	var root = GameManager.current_key
	# Center around C3 (48) or C4 (60)
	var bass = 48 + root
	if bass > 59: bass -= 12
	
	var chord_intervals = [0, 4, 7] # Major
	if GameManager.current_mode == MusicTheory.ScaleMode.MINOR:
		chord_intervals = [0, 3, 7] # Minor
		
	var notes = []
	for i in chord_intervals:
		notes.append(bass + i)
		
	# Quick strum
	for i in range(notes.size()):
		AudioEngine.play_note(notes[i], -1) # -1 string for generic playback
		await manager.get_tree().create_timer(0.05).timeout

func _find_target_pos_with_constraint(target_note: int, root_str: int, root_fret: int, constraint: int) -> Dictionary:
	# 0=All, 1=Same, 2=Cross
	var MAX_FRET = 12 # [Fix] Strict 12 fret limit
	
	if constraint == 0:
		# Even for "All", we should ensure there IS a position <= 12
		for s in range(6):
			var f = target_note - AudioEngine.OPEN_STRING_MIDI[s]
			if f >= 0 and f <= MAX_FRET:
				return {"valid": true, "string": s, "fret": f} # Return specific valid one?
		return {"valid": false}
	
	if constraint == 1: # SAME STRING
		# Check if target note exists on root_str within reasonable fret range
		var f = target_note - AudioEngine.OPEN_STRING_MIDI[root_str]
		if f >= 0 and f <= MAX_FRET: # Playable range
			# Also avoid extreme stretches
			return {"valid": true, "string": root_str, "fret": f}
		return {"valid": false}
		
	if constraint == 2: # CROSS STRING (Adjacent string)
		# Look for target on string +/- 1
		for s in [root_str - 1, root_str + 1]:
			if s >= 0 and s < 6:
				var f = target_note - AudioEngine.OPEN_STRING_MIDI[s]
				if f >= 0 and f <= MAX_FRET:
					# Check stretch. Cross string usually implies close frets.
					if abs(f - root_fret) <= 6:
						return {"valid": true, "string": s, "fret": f}
		return {"valid": false}
		
	return {"valid": true}

func replay() -> void:
	manager._stop_playback()
	var my_id = manager._current_playback_id
	var root = manager.interval_root_note
	var target = manager.interval_target_note
	var mode = manager.current_interval_mode
	
	if mode == manager.IntervalMode.HARMONIC:
		manager._play_note_with_blink(root, 1.0, true)
		manager._play_note_with_blink(target, 1.0, false)
	elif mode == manager.IntervalMode.DESCENDING:
		manager._play_note_with_blink(root, 0.6, true)
		manager.get_tree().create_timer(0.6).timeout.connect(func():
			if manager._current_playback_id != my_id: return
			manager._play_note_with_blink(target, 1.0, false)
		)
	else: # ASCENDING
		manager._play_note_with_blink(root, 0.6, true)
		manager.get_tree().create_timer(0.6).timeout.connect(func():
			if manager._current_playback_id != my_id: return
			manager._play_note_with_blink(target, 1.0, false)
		)
