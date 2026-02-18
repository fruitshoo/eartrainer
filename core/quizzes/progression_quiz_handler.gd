class_name ProgressionQuizHandler
extends BaseQuizHandler

var current_progression: Array = []
var current_progression_name: String = ""
var user_input_sequence: Array = []
var is_playing_sequence: bool = false
var current_step_index: int = 0

# Progression data ref
const ChordData = preload("res://core/data/chord_quiz_data.gd")
const MusicTheory = preload("res://core/music_theory.gd")

func start_quiz() -> void:
	# 1. Filter progressions based on selected degrees
	var available_progressions = []
	var selected_degrees = manager.active_progression_degrees
	
	for name in ChordData.DIATONIC_PROGRESSIONS:
		var progression = ChordData.DIATONIC_PROGRESSIONS[name]
		var is_valid = true
		for deg in progression:
			if deg not in selected_degrees:
				is_valid = false
				break
		if is_valid:
			available_progressions.append(name)
			
	# Fallback if no exact match (pick any if none match the filter)
	if available_progressions.is_empty():
		available_progressions = ChordData.DIATONIC_PROGRESSIONS.keys()
	
	current_progression_name = available_progressions.pick_random()
	current_progression = ChordData.DIATONIC_PROGRESSIONS[current_progression_name].duplicate()
	
	# 2. Reset state
	user_input_sequence.clear()
	current_step_index = 0
	manager._clear_markers() # [New] Clear previous highlights
	
	# 3. Notify start (UI will prepare slots)
	manager.quiz_started.emit({
		"type": "progression",
		"length": current_progression.size(),
		"name": current_progression_name
	})
	
	# 4. Play the sequence
	play_full_sequence()

func replay() -> void:
	manager._clear_markers()
	play_full_sequence()

func on_tile_clicked(note: int, string_idx: int) -> void:
	if is_playing_sequence: return
	if current_step_index >= current_progression.size(): return
	
	# Convert Note -> Degree
	var key_root = GameManager.current_key
	var mode = GameManager.current_mode
	
	# Check if note is in scale
	if not MusicTheory.is_in_scale(note, key_root, mode):
		return
		
	# Find degree index (0-based)
	var intervals = MusicTheory.SCALE_INTERVALS[mode]
	var interval = (note - key_root) % 12
	if interval < 0: interval += 12
	
	var degree_idx = intervals.find(interval)
	if degree_idx != -1:
		on_degree_clicked(degree_idx, string_idx)

func play_full_sequence() -> void:
	if is_playing_sequence: return
	is_playing_sequence = true
	
	var key_root = GameManager.current_key
	var scale_mode = GameManager.current_mode
	
	# Play Sequence
	for i in range(current_progression.size()):
		var degree_idx = current_progression[i]
		
		# Calculate Chord Root & Type
		var chord_info = _get_chord_info_for_degree(degree_idx, key_root, scale_mode)
		var notes = chord_info.notes
		
		# Highlight logic (optional, maybe just show progress?)
		# manager.highlight_degree(degree_idx) 
		
		# Play Chord
		for note in notes:
			AudioEngine.play_note(note)
			
		await manager.get_tree().create_timer(1.2).timeout # Gap
		
	is_playing_sequence = false

func on_degree_clicked(degree_idx: int, string_idx: int = -1) -> void:
	if is_playing_sequence: return
	if current_step_index >= current_progression.size(): return
	
	var expected_degree = current_progression[current_step_index]
	
	# Play the clicked chord for feedback
	_play_chord_for_degree(degree_idx)
	
	if degree_idx == expected_degree:
		# Correct!
		user_input_sequence.append(degree_idx)
		current_step_index += 1
		
		# [New] Update fretboard highlight (Persistent)
		if string_idx != -1:
			var scale_intervals = MusicTheory.SCALE_INTERVALS[GameManager.current_mode]
			var interval = scale_intervals[degree_idx]
			var note = GameManager.current_key + interval
			# We need the actual fret for the clicked string
			var fret = note - AudioEngine.OPEN_STRING_MIDI[string_idx]
			while fret < 0: fret += 12 # Octave adj if needed
			while fret > 16: fret -= 12 # Limit to playable range for visual
			manager.highlight_found_tone(string_idx, fret)
		
		manager.quiz_step_completed.emit({
			"step": current_step_index,
			"total": current_progression.size(),
			"correct": true,
			"degree": degree_idx
		})
		
		if current_step_index >= current_progression.size():
			_finish_quiz()
	else:
		# Wrong!
		manager.quiz_step_completed.emit({
			"step": current_step_index,
			"correct": false,
			"degree": degree_idx
		})
		# Visual Shake/Feedback handled by UI
		
func _finish_quiz() -> void:
	AudioEngine.play_sfx("correct")
	manager.quiz_answered.emit({"correct": true})
	await manager.get_tree().create_timer(1.0).timeout
	start_quiz()

func _play_chord_for_degree(degree_idx: int) -> void:
	var key_root = GameManager.current_key
	var scale_mode = GameManager.current_mode
	var info = _get_chord_info_for_degree(degree_idx, key_root, scale_mode)
	for note in info.notes:
		AudioEngine.play_note(note)

func _get_chord_info_for_degree(degree_idx: int, key_root: int, mode: int) -> Dictionary:
	# Basic Triad Logic for now
	# 0=I, 1=ii, etc.
	# We need to know if it's Major or Minor based on key/mode
	# Simplified Diatonic logic:
	var scale_intervals = MusicTheory.SCALE_INTERVALS[mode]
	var degree_semitone = scale_intervals[degree_idx]
	
	var root_note = key_root + degree_semitone + 48 # Octave 3/4
	
	# Determine quality (Maj/Min/Dim)
	# Check 3rd and 5th relative to root within scale
	
	# Shortcuts for Major Scale (Mode 0):
	# I(M), ii(m), iii(m), IV(M), V(M), vi(m), vii(dim)
	var quality = "Major"
	if mode == MusicTheory.ScaleMode.MAJOR:
		if degree_idx in [1, 2, 5]: quality = "Minor"
		if degree_idx == 6: quality = "Diminished"
	elif mode == MusicTheory.ScaleMode.MINOR:
		# i(m), ii(dim), III(M), iv(m), v(m), VI(M), VII(M)
		if degree_idx in [0, 3, 4]: quality = "Minor"
		if degree_idx == 1: quality = "Diminished"
		
	var intervals = ChordData.CHORD_QUALITIES[quality]
	var notes = []
	for iv in intervals:
		notes.append(root_note + iv)
		
	return {"root": root_note, "notes": notes, "quality": quality}
