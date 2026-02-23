class_name ProgressionQuizHandler
extends BaseQuizHandler

var current_progression: Array = []
var current_progression_name: String = ""
var user_input_sequence: Array = []
var _found_markers: Array = [] # [New] Cache correct answers to persist green highlights
var is_playing_sequence: bool = false
var current_step_index: int = 0

# Progression data ref
const ChordData = preload("res://core/data/chord_quiz_data.gd")
const MusicTheory = preload("res://core/music_theory.gd")

func start_quiz() -> void:
	var selected_degrees = manager.active_progression_degrees
	
	# Fallback if no degrees selected (shouldn't happen but safe)
	if selected_degrees.is_empty():
		selected_degrees = [0, 3, 4, 5]
		
	# Determine target length from level (Level 1 = 2 chords, Level 2 = 3 chords, etc)
	# Max length 8
	var target_length = clampi(manager.progression_level + 1, 2, 8)
	
	current_progression.clear()
	
	# Procedural Generation (Markov Chain based on Functional Harmony)
	# 1. Pick starting chord (Prefer Tonic/0 if enabled, else random)
	var current_chord = 0
	if 0 in selected_degrees:
		current_chord = 0
	else:
		current_chord = selected_degrees.pick_random()
		
	current_progression.append(current_chord)
	
	# 2. Build the rest of the sequence
	var attempts = 0
	while current_progression.size() < target_length and attempts < 50:
		attempts += 1
		
		# Get functional harmony transitions for current chord
		var preferred_nexts = ChordData.DIATONIC_TRANSITIONS.get(current_chord, [])
		
		# Filter transitions by what the user has enabled in settings
		var valid_nexts = []
		for n in preferred_nexts:
			if n in selected_degrees:
				valid_nexts.append(n)
				
		var next_chord = -1
		if not valid_nexts.is_empty():
			# Pick a musically pleasing next chord
			next_chord = valid_nexts.pick_random()
		else:
			# Fallback: User settings created a functional dead-end. 
			# Pick any random enabled chord to keep the quiz flowing.
			next_chord = selected_degrees.pick_random()
			
		current_progression.append(next_chord)
		current_chord = next_chord

	# Create a procedural name for UI purposes
	current_progression_name = "Procedural (Level %d)" % manager.progression_level
	
	# 2. Reset state
	user_input_sequence.clear()
	_found_markers.clear()
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

func stop_playback() -> void:
	is_playing_sequence = false
	_playback_id += 1 # Invalidate any running loops

# Playback ID for race condition safety
var _playback_id: int = 0

func on_tile_clicked(note: int, string_idx: int) -> void:
	# if is_playing_sequence: return # [User Request] Allow input during playback
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
		var fret = note - AudioEngine.OPEN_STRING_MIDI[string_idx]
		on_degree_clicked(degree_idx, string_idx, fret)

func play_full_sequence() -> void:
	# Cancel previous playback
	_playback_id += 1
	var my_id = _playback_id
	
	is_playing_sequence = true
	
	var key_root = GameManager.current_key
	var scale_mode = GameManager.current_mode
	
	# Play Sequence
	for i in range(current_progression.size()):
		# Race condition check: If quiz reset, abort
		if _playback_id != my_id:
			is_playing_sequence = false
			return
			
		var degree_idx = current_progression[i]
		
		# Calculate Chord Root & Type
		var chord_info = _get_chord_info_for_degree(degree_idx, key_root, scale_mode)
		var notes = chord_info.notes
		
		# Highlight logic (if enabled)
		if GameManager.show_target_visual:
			# print("[ProgressionHandler] Highlighting degree: ", degree_idx)
			manager.highlight_degree(degree_idx)
		
		# Play Chord
		var shift = _get_anchored_root_note(chord_info.root) - chord_info.root
		manager.quiz_sequence_playing.emit(i) # [New] Tell UI to highlight the current slot
		for note in notes:
			AudioEngine.play_note(note + shift)
			
		await manager.get_tree().create_timer(1.0).timeout # [Refined] Snappier tempo (was 1.2s)
		
	if _playback_id == my_id:
		is_playing_sequence = false
		manager._clear_markers() # Clean up after sequence
		_update_visual_hint() # [New] Show hint for current step if enabled

func on_degree_clicked(degree_idx: int, string_idx: int = -1, fret_idx: int = -1) -> void:
	# if is_playing_sequence: return # [User Request] Allow input during playback
	if current_step_index >= current_progression.size(): return
	
	var expected_degree = current_progression[current_step_index]
	
	# Play the clicked chord for feedback
	_play_chord_for_degree(degree_idx)
	
	if degree_idx == expected_degree:
		# Correct!
		user_input_sequence.append(degree_idx)
		current_step_index += 1
		
		# [New] Update fretboard highlight (Persistent)
		if string_idx != -1 and fret_idx != -1:
			_found_markers.append({"string": string_idx, "fret": fret_idx})
			manager.highlight_found_tone(string_idx, fret_idx)
		
		manager.quiz_step_completed.emit({
			"step": current_step_index,
			"total": current_progression.size(),
			"correct": true,
			"degree": degree_idx
		})
		
		if current_step_index >= current_progression.size():
			_finish_quiz()
		else:
			_update_visual_hint() # [New] Update hint to next slot
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
	manager._clear_markers() # Clear hint when finishing
	await manager.get_tree().create_timer(0.8).timeout # [Refined] Snappier auto-advance
	start_quiz()

func _update_visual_hint() -> void:
	# [New] Keep the root notes of the remaining targets highlighted if hints are enabled
	if not GameManager.show_target_visual: return
	
	manager._clear_markers()
	
	# Redraw found markers in green
	for m in _found_markers:
		manager.highlight_found_tone(m.string, m.fret)
	
	if current_step_index >= current_progression.size(): return
	
	# User Request: Highlight ALL remaining chords in the sequence at once so they can pick them in order
	for i in range(current_step_index, current_progression.size()):
		var degree_idx = current_progression[i]
		manager.highlight_degree(degree_idx, false)

# [New] Helper to get an anchored root note position for chords
func _get_anchored_root_note(root_note: int) -> int:
	var pitch_class = root_note % 12
	if pitch_class < 0: pitch_class += 12
	var anchor = manager._find_closest_root_for_pitch_class(pitch_class)
	# If we found a valid position near the anchor, use that specific octave
	if anchor.valid:
		return anchor.midi_note
	return root_note

func _play_chord_for_degree(degree_idx: int) -> void:
	var key_root = GameManager.current_key
	var scale_mode = GameManager.current_mode
	var info = _get_chord_info_for_degree(degree_idx, key_root, scale_mode)
	
	# Adjust playback octave to stay near anchor
	var shift = _get_anchored_root_note(info.root) - info.root
	for note in info.notes:
		AudioEngine.play_note(note + shift)

func _get_chord_info_for_degree(degree_idx: int, key_root: int, mode: int) -> Dictionary:
	# Basic Triad Logic for now
	# 0=I, 1=ii, etc.
	# We need to know if it's Major or Minor based on key/mode
	# Simplified Diatonic logic:
	# 1. Get interval and root note for this degree
	var scale_intervals = MusicTheory.SCALE_INTERVALS[mode]
	
	# [Fix] Bounds check: If mode is Pentatonic (size 5) but degree is 6 (vii), prevent crash
	if degree_idx >= scale_intervals.size():
		GameLogger.error("[ProgressionHandler] Degree %d out of bounds for mode %d" % [degree_idx, mode])
		return {"root": 60, "notes": [], "quality": "Major"} # Fallback
		
	var degree_semitone = scale_intervals[degree_idx]
	var root_note = key_root + degree_semitone + 48 # Octave 3/4
	
	# 2. Dynamic Quality Resolution via MusicTheory
	# Note: get_diatonic_type returns "M7", "m7", "7", etc.
	# We need to map these to simple Triads ("Major", "Minor", "Diminished") for the quiz data
	# OR update ChordQuizData to support 7th chords.
	# For now, let's map back to simple strings used in ChordData.CHORD_QUALITIES
	
	var type_7th = MusicTheory.get_diatonic_type(root_note, key_root, mode)
	var quality = "Major"
	
	if manager.use_power_chords: # [New] Power Chord override
		quality = "Power"
	else:
		if type_7th.begins_with("m") and not type_7th.begins_with("maj"): # m7, m7b5
			quality = "Minor"
			if "b5" in type_7th or "dim" in type_7th:
				quality = "Diminished"
		elif type_7th.begins_with("dim"):
			quality = "Diminished"
		# else Major (M7, 7)
	
	var intervals = ChordData.CHORD_QUALITIES[quality]
	var notes = []
	
	# Assemble raw notes
	for iv in intervals:
		notes.append(root_note + iv)
		
	return {"root": root_note, "notes": notes, "quality": quality}
