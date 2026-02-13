# interval_quiz_handler.gd
extends BaseQuizHandler
class_name IntervalQuizHandler

var interval_root_note: int = -1
var interval_target_note: int = -1
var interval_semitones: int = 0
var current_interval_mode: int = 0 # IntervalMode enum in manager

func start_quiz() -> void:
	manager._stop_playback()
	manager._clear_markers()
	manager._is_processing_correct_answer = false
	
	manager.current_quiz_type = manager.QuizType.INTERVAL
	
	var active_intervals = manager.active_intervals
	if active_intervals.is_empty():
		print("[IntervalQuizHandler] No intervals selected!")
		return

	# 1. Select Interval
	interval_semitones = active_intervals.pick_random()
	
	# 2. Determine Mode
	if manager.active_modes.is_empty():
		current_interval_mode = 0 # ASCENDING
	else:
		current_interval_mode = manager.active_modes.pick_random()
		
	# 3. Find Valid Position (Near Player)
	var center_fret = GameManager.player_fret
	if center_fret < 0: center_fret = 0
	
	var valid_found = false
	var max_retries = 20
	var final_string_idx = -1
	var final_fret_idx = -1
	
	var key_root = GameManager.current_key
	var key_mode = GameManager.current_mode
	
	for i in range(max_retries):
		var root_string = randi() % 4 + 1 # String 2-5
		var root_fret = center_fret + (randi() % 3 - 1)
		root_fret = clampi(root_fret, 0, 12)
		
		var string_bases = [40, 45, 50, 55, 59, 64]
		var candidate_root = string_bases[root_string] + root_fret
		
		var candidate_target = -1
		if current_interval_mode == 1: # DESCENDING
			candidate_target = candidate_root - interval_semitones
		else:
			candidate_target = candidate_root + interval_semitones
			
		if candidate_target < 40 or candidate_target > 76:
			continue
			
		var root_in_scale = MusicTheory.is_in_scale(candidate_root, key_root, key_mode)
		var target_in_scale = MusicTheory.is_in_scale(candidate_target, key_root, key_mode)
		
		if root_in_scale and target_in_scale:
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
	manager._highlight_tile(final_string_idx, final_fret_idx, Color.MAGENTA)
	
	# Play
	manager.play_current_interval()
	
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
		is_correct = (abs(clicked_note - interval_root_note) == interval_semitones)
		
	var fret_idx = MusicTheory.get_fret_position(clicked_note, string_idx)
	var tile = GameManager.find_tile(string_idx, fret_idx)
	
	if is_correct:
		manager._is_processing_correct_answer = true
		_play_sfx("correct")
		
		if tile and tile.has_method("_show_rhythm_feedback"):
			tile.call("_show_rhythm_feedback", {"rating": "Perfect!", "color": Color.CYAN})
		
		# Show both
		var root_pos = manager._find_valid_pos_for_note(interval_root_note, manager._current_root_fret)
		if root_pos.valid:
			manager._highlight_tile(root_pos.string, root_pos.fret, Color.MAGENTA)
		manager._highlight_tile(string_idx, fret_idx, Color.MAGENTA)
		
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
	var max_fret = min(12, center_fret + 3) # Max fret is 12 in this game
	var root_fret = randi_range(min_fret, max_fret)
	
	var string_bases = [40, 45, 50, 55, 59, 64]
	interval_root_note = string_bases[root_string] + root_fret
	
	if current_interval_mode == 1: # DESCENDING
		interval_target_note = interval_root_note - interval_semitones
	else:
		interval_target_note = interval_root_note + interval_semitones
		
	if interval_target_note < 40: 
		interval_target_note = 40; 
		interval_root_note = 40 + interval_semitones
	if interval_target_note > 80: 
		interval_target_note = 80; 
		interval_root_note = 80 - interval_semitones
