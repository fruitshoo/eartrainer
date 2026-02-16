# chord_quiz_handler.gd
extends BaseQuizHandler
class_name ChordQuizHandler

var chord_target_type: String = ""

func start_quiz() -> void:
	manager._stop_playback()
	manager._auto_hide_visuals()
	
	manager.current_quiz_type = manager.QuizType.CHORD_QUALITY
	
	var active_types = manager.active_chord_types
	if active_types.is_empty():
		print("[ChordQuizHandler] No chord types selected!")
		return
		
	# 1. Select Target Chord Type
	chord_target_type = active_types.pick_random()
	
	# 2. Select Root
	var root_note = 60
	if manager.chord_root_mode == "random":
		root_note = randi_range(48, 64) # C3 - E4 range
	else:
		root_note = manager.chord_fixed_root
		if randf() > 0.5: root_note -= 12
		
	# Sync back to manager for playback
	manager.chord_target_type = chord_target_type
	manager.interval_root_note = root_note
	
	print("[ChordQuizHandler] Chord Quiz: %s on Root %d" % [chord_target_type, root_note])
	
	# 3. Play
	manager._play_quiz_sound(manager.QuizType.CHORD_QUALITY)
	
	manager.quiz_started.emit({
		"type": "chord",
		"target": chord_target_type
	})

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

func _play_chord_structure(root: int, type: String):
	var intervals = ChordQuizData.get_chord_intervals(type).duplicate()
	if intervals.is_empty(): return
	
	# 1. Apply Inversion
	var inversion = manager.chord_inversion_mode
	if inversion == 3: inversion = randi() % 3 # Random (Root, 1st, 2nd)
	
	# Inversion shift: take the lowest notes and move them up an octave
	for i in range(inversion):
		if intervals.size() > 0:
			var low_note = intervals.pop_front()
			intervals.push_back(low_note + 12)
	
	intervals.sort() # Keep sorted for direction logic
	
	# 2. Determine Playback order and timing
	var direction = manager.chord_playback_direction
	if direction == 3: direction = randi() % 3 # Random (Up, Down, Harmonic)
	
	var playback_notes = []
	for interval in intervals:
		playback_notes.append(root + interval)
		
	var delay_step = 0.4 # Arpeggio speed
	
	match direction:
		1: # Down
			playback_notes.reverse()
		2: # Harmonic (Strum)
			delay_step = 0.05
			
	# 3. Schedule Playback
	var my_id = manager._current_playback_id
	for i in range(playback_notes.size()):
		var note = playback_notes[i]
		var delay = i * delay_step
		
		manager.get_tree().create_timer(delay).timeout.connect(func():
			if manager._current_playback_id != my_id: return
			AudioEngine.play_note(note)
			# Optional: Visual highlight on fretboard for the played note?
			# EventBus.visual_note_on.emit(note, 0)
		)
