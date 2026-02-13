# pitch_quiz_handler.gd
extends BaseQuizHandler
class_name PitchQuizHandler

# --- Specialized State ---
var pitch_target_class: int = -1 # 0-11
var pitch_target_note_actual: int = -1 # Actual midi note played

func start_quiz() -> void:
	# 1. Reset visual markers via manager
	manager._stop_playback()
	manager._clear_markers()
	
	# 2. Auto-Hide Visual Cheats (Handled by manager or here?)
	# Let's let manager handle global visual state for now
	manager._auto_hide_visuals()
	
	manager.current_quiz_type = manager.QuizType.PITCH_CLASS
	
	var active_pitch_classes = manager.active_pitch_classes
	if active_pitch_classes.is_empty():
		print("[PitchQuizHandler] No pitch classes selected!")
		return
		
	# 3. Select Target Pitch Class
	pitch_target_class = active_pitch_classes.pick_random()
	
	# 4. Select Octave (Range 45-70 approx)
	var octave = randi_range(3, 5)
	pitch_target_note_actual = (octave * 12) + pitch_target_class
	
	if pitch_target_note_actual < 40: pitch_target_note_actual += 12
	if pitch_target_note_actual > 80: pitch_target_note_actual -= 12
	
	# Transposition anchor
	manager.interval_root_note = pitch_target_note_actual
	
	print("[PitchQuizHandler] Pitch Quiz: Target Class %d (%s), Note %d" % [
		pitch_target_class,
		PitchQuizData.get_pitch_info(pitch_target_class).name,
		pitch_target_note_actual
	])
	
	# 5. Play Sound
	manager._play_quiz_sound(manager.QuizType.PITCH_CLASS)
	
	# 6. Signal
	manager.quiz_started.emit({
		"type": "pitch",
		"target_class": pitch_target_class
	})

func on_tile_clicked(clicked_note: int, string_idx: int) -> void:
	if manager._is_processing_correct_answer: return
	
	var clicked_class = clicked_note % 12
	var is_correct = (clicked_class == pitch_target_class)
	
	var fret_idx = MusicTheory.get_fret_position(clicked_note, string_idx)
	var tile = GameManager.find_tile(string_idx, fret_idx)
	
	if is_correct:
		manager._is_processing_correct_answer = true
		print("[PitchQuizHandler] Correct Pitch!")
		_play_sfx("correct")
		
		# Visual Feedback
		if tile and tile.has_method("_show_rhythm_feedback"):
			tile.call("_show_rhythm_feedback", {
					"rating": "Yes! " + PitchQuizData.get_pitch_info(pitch_target_class).name,
					"color": Color.MAGENTA
				})
				
		# Play Reward
		var reward_duration = manager._play_reward_song(pitch_target_class, 0) # 0 = Ascending
		
		manager.quiz_answered.emit({"correct": true, "pitch_class": pitch_target_class})
		
		var wait_time = reward_duration + 1.0 if reward_duration > 0 else 1.0
		var my_id = manager._current_playback_id
		
		await manager.get_tree().create_timer(wait_time).timeout
		
		# Re-verify state after await
		if manager._current_playback_id != my_id: return
		if manager.current_quiz_type != manager.QuizType.PITCH_CLASS: return
		
		start_quiz()
		
	else:
		print("[PitchQuizHandler] Wrong Pitch.")
		_play_sfx("wrong")
		
		if tile and tile.has_method("_show_rhythm_feedback"):
			tile.call("_show_rhythm_feedback", {
					"rating": PitchQuizData.get_pitch_info(clicked_class).name,
					"color": Color.TOMATO
				})
		
		manager.quiz_answered.emit({"correct": false, "pitch_class": pitch_target_class})
