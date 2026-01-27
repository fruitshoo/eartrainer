extends Node

# ============================================================
# SIGNALS
# ============================================================
signal quiz_started(data: Dictionary) # { "type": "note"|"interval", ... }
signal quiz_answered(result: Dictionary) # { "correct": bool, "answer": ..., "target": ... }

# ============================================================
# ENUMS
# ============================================================
enum QuizType {NONE, NOTE_LOCATION, INTERVAL}
enum IntervalMode {ASCENDING, DESCENDING, HARMONIC}

# ============================================================
# STATE
# ============================================================
var current_quiz_type: QuizType = QuizType.NONE

# -- Note Quiz State --
var current_target_note: int = -1

# -- Interval Quiz State --
var interval_root_note: int = -1
var interval_target_note: int = -1
var interval_semitones: int = 0
# Settings
var active_modes: Array = [IntervalMode.ASCENDING] # Default
var active_intervals: Array = [0, 2, 4, 5, 7, 9, 11, 12] # Default Major Scale intervals
var one_octave_limit: bool = true
# Current Question State
var current_interval_mode: IntervalMode = IntervalMode.ASCENDING

# ============================================================
# LIFECYCLE
# ============================================================
func _ready():
	EventBus.tile_clicked.connect(_on_tile_clicked)

func _on_tile_clicked(note: int, string_idx: int, _modifiers: Dictionary):
	# Dispatch based on active quiz type
	if current_quiz_type == QuizType.NOTE_LOCATION:
		check_note_answer(note)
	elif current_quiz_type == QuizType.INTERVAL:
		check_interval_answer_with_tile(note, string_idx)

# ============================================================
# CORE FUNCTIONS
# ============================================================

func stop_quiz():
	current_quiz_type = QuizType.NONE
	_clear_root_highlight()
	print("[QuizManager] Quiz Stopped.")

func start_note_quiz():
	current_quiz_type = QuizType.NOTE_LOCATION
	
	# 6줄 12프렛 범위 내에서 랜덤한 MIDI 번호 추출
	var random_string = randi() % 6
	var random_fret = randi() % 13
	
	var root_notes = [40, 45, 50, 55, 59, 64]
	current_target_note = root_notes[random_string] + random_fret
	
	AudioEngine.play_note(current_target_note)
	quiz_started.emit({
		"type": "note",
		"target": current_target_note
	})
	print("[QuizManager] Note Quiz: ", current_target_note)

func check_note_answer(clicked_note: int):
	if current_quiz_type != QuizType.NOTE_LOCATION: return
	
	var is_correct = (clicked_note == current_target_note)
	
	if is_correct:
		# AudioEngine.play_sfx("correct") # Todo
		print("Correct!")
		await get_tree().create_timer(1.0).timeout
		start_note_quiz() # Auto Next
	else:
		# AudioEngine.play_sfx("wrong") # Todo
		print("Wrong, try again.")
		AudioEngine.play_note(current_target_note)
		
	quiz_answered.emit({"correct": is_correct})


# ============================================================
# INTERVAL QUIZ LOGIC
# ============================================================

func start_interval_quiz():
	_stop_playback()
	_is_processing_correct_answer = false
	
	current_quiz_type = QuizType.INTERVAL
	
	if active_intervals.is_empty():
		print("[QuizManager] No intervals selected!")
		return

	# 1. Select Interval (First, to know what we are looking for)
	interval_semitones = active_intervals.pick_random()
	
	# 2. Determine Mode
	if active_modes.is_empty():
		current_interval_mode = IntervalMode.ASCENDING
		print("[QuizManager] Active modes empty! Defaulting to ASCENDING.")
	else:
		current_interval_mode = active_modes.pick_random()
		
	print("[QuizManager] Active Modes: ", active_modes, " Selected: ", current_interval_mode)
	
	# 3. Find Valid Diatonic Question (Root + Target in Scale) near Player
	# Retrieve Player Position
	var center_fret = GameManager.player_fret
	if center_fret < 0: center_fret = 0
	
	# Attempt to find a valid diatonic pair
	var valid_found = false
	var max_retries = 20
	var final_string_idx = -1
	var final_fret_idx = -1
	
	# Key Context
	var key_root = GameManager.current_key
	var key_mode = GameManager.current_mode
	
	for i in range(max_retries):
		# A. Pick Root Candidates near player
		var root_string = randi() % 4 + 1 # String 2-5
		var root_fret = center_fret + (randi() % 3 - 1) # +/- 1 fret strict
		root_fret = clampi(root_fret, 0, 12)
		
		var string_bases = [40, 45, 50, 55, 59, 64]
		var candidate_root = string_bases[root_string] + root_fret
		
		# B. Calculate Target
		var candidate_target = -1
		if current_interval_mode == IntervalMode.DESCENDING:
			candidate_target = candidate_root - interval_semitones
		else:
			# Harmonic or Ascending uses +semitones logic for base target calculation?
			# Actually Harmonic is simultaneous, but conceptually target is usually higher unless specified.
			# Let's keep consistent: Asc/Harmonic = Up, Desc = Down
			candidate_target = candidate_root + interval_semitones
			
		# C. Bound Check (40-76)
		if candidate_target < 40 or candidate_target > 76:
			continue
			
		# D. Diatonic Check (Both Root and Target must be in Scale)
		var root_in_scale = MusicTheory.is_in_scale(candidate_root, key_root, key_mode)
		var target_in_scale = MusicTheory.is_in_scale(candidate_target, key_root, key_mode)
		
		if root_in_scale and target_in_scale:
			interval_root_note = candidate_root
			interval_target_note = candidate_target
			final_string_idx = root_string
			final_fret_idx = root_fret
			valid_found = true
			break
			
	if not valid_found:
		# Fallback: Just pick a safe valid position even if chromatic
		print("[QuizManager] Could not find diatonic pair, using chromatic fallback.")
		_pick_fallback_question(center_fret)
		# Fallback doesn't set string/fret explicitly, so we might need reverse lookup or update fallback
		var pos = _find_valid_pos_for_note(interval_root_note)
		if pos.valid:
			final_string_idx = pos.string
			final_fret_idx = pos.fret

	_highlight_tile(final_string_idx, final_fret_idx, Color.ORANGE)
	
	# 4. Play
	play_current_interval()
	
	quiz_started.emit({
		"type": "interval",
		"root": interval_root_note,
		"target": interval_target_note,
		"mode": current_interval_mode
	})
	print("[QuizManager] Interval Quiz: %d -> %d (%d semits)" % [interval_root_note, interval_target_note, interval_semitones])

func _pick_fallback_question(center_fret: int):
	# Pick a valid root/target near the player (center_fret)
	var root_string = randi() % 6 # 0 to 5
	
	# Pick fret near center (player)
	var min_fret = max(0, center_fret - 3)
	var max_fret = min(19, center_fret + 3)
	var root_fret = randi_range(min_fret, max_fret)
	
	var string_bases = [40, 45, 50, 55, 59, 64]
	interval_root_note = string_bases[root_string] + root_fret
	
	if current_interval_mode == IntervalMode.DESCENDING:
		interval_target_note = interval_root_note - interval_semitones
	else:
		interval_target_note = interval_root_note + interval_semitones
		
	# Simple clamp
	if interval_target_note < 40: interval_target_note = 40; interval_root_note = 40 + interval_semitones
	if interval_target_note > 84: interval_target_note = 84; interval_root_note = 84 - interval_semitones

var _last_root_tile: Node = null

# Helper to find a valid string/fret for a given MIDI note
# Prioritizes positions close to preferred_fret (defaults to player_fret)
func _find_valid_pos_for_note(midi_note: int, preferred_fret: int = -1) -> Dictionary:
	if preferred_fret == -1:
		preferred_fret = GameManager.player_fret
		
	var candidates = []
	var open_notes = [40, 45, 50, 55, 59, 64] # Index 0 to 5
	
	for s_idx in range(6):
		var fret = midi_note - open_notes[s_idx]
		if fret >= 0 and fret <= 19: # 19 frets usually
			var dist = abs(fret - preferred_fret)
			candidates.append({"valid": true, "string": s_idx, "fret": fret, "dist": dist})
			
	if candidates.is_empty():
		return {"valid": false, "string": - 1, "fret": - 1}
		
	# Sort by distance to preferred fret
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	
	return candidates[0]

func _highlight_tile(string_idx: int, fret_idx: int, color: Color):
	var tile = GameManager.find_tile(string_idx, fret_idx)
	if tile and tile.has_method("apply_sequencer_highlight"):
		tile.apply_sequencer_highlight(color, 2.0)
		_last_root_tile = tile
		
	# Also ensure camera follows if needed? No, leave camera to user or GameManager logic.
	# But ensure this tile is the one used for the visual anchor.

func _clear_root_highlight():
	if _last_root_tile and is_instance_valid(_last_root_tile):
		if _last_root_tile.has_method("clear_sequencer_highlight"):
			_last_root_tile.clear_sequencer_highlight()
	_last_root_tile = null

func play_current_interval():
	if current_quiz_type != QuizType.INTERVAL: return
	var my_id = _current_playback_id
	
	# Pulse the root visual again when playing?
	if _last_root_tile and is_instance_valid(_last_root_tile):
		_last_root_tile.apply_sequencer_highlight(Color.YELLOW, 2.0)
	
	if current_interval_mode == IntervalMode.HARMONIC:
		AudioEngine.play_note(interval_root_note)
		AudioEngine.play_note(interval_target_note)
	elif current_interval_mode == IntervalMode.DESCENDING:
		AudioEngine.play_note(interval_root_note)
		await get_tree().create_timer(0.6).timeout
		AudioEngine.play_note(interval_target_note)
	else: # ASCENDING
		AudioEngine.play_note(interval_root_note)
		await get_tree().create_timer(0.6).timeout
		if _current_playback_id != my_id: return # Abort if interrupted
		AudioEngine.play_note(interval_target_note)

func check_interval_answer(semitones: int):
	# Legacy/Button based answer
	pass

func check_interval_answer_with_tile(clicked_note: int, string_idx: int):
	# Prevent multiple triggers while reward is playing
	if _is_processing_correct_answer:
		return

	# Calculate correctness
	var is_correct = false
	
	if current_interval_mode == IntervalMode.ASCENDING:
		is_correct = (clicked_note == interval_target_note)
	elif current_interval_mode == IntervalMode.DESCENDING:
		is_correct = (clicked_note == interval_target_note)
	elif current_interval_mode == IntervalMode.HARMONIC:
		is_correct = (abs(clicked_note - interval_root_note) == interval_semitones)
		
	# Find Tile for Visual Feedback
	var fret_idx = MusicTheory.get_fret_position(clicked_note, string_idx)
	var tile = GameManager.find_tile(string_idx, fret_idx)
	
	if is_correct:
		_is_processing_correct_answer = true
		print("Correct! Reward Time!")
		
		# SFX
		AudioEngine.play_sfx("correct")
		
		# Feedback Visual: Perfect!
		if tile and tile.has_method("_show_rhythm_feedback"):
			tile.call("_show_rhythm_feedback", {
				"rating": "Perfect!",
				"color": Color.CYAN
			})
		
		var reward_duration = _play_reward_song(interval_semitones, current_interval_mode)
		
		quiz_answered.emit({"correct": true, "interval": interval_semitones})
		
		_clear_root_highlight()
		
		# Dynamic delay: Wait for song + buffer
		var my_id = _current_playback_id
		var wait_time = reward_duration + 1.0 if reward_duration > 0 else 1.0
		
		await get_tree().create_timer(wait_time).timeout
		
		# Guard: If interrupted (New Question pressed), don't auto-start
		if _current_playback_id != my_id:
			return
			
		# Guard: If quiz type changed
		if current_quiz_type != QuizType.INTERVAL:
			return
			
		start_interval_quiz()
	else:
		print("Wrong.")
		# SFX
		AudioEngine.play_sfx("wrong")
		
		# Feedback Visual: Wrong
		if tile and tile.has_method("_show_rhythm_feedback"):
			tile.call("_show_rhythm_feedback", {
				"rating": "Try Again",
				"color": Color.RED
			})
			
		play_current_interval()
		quiz_answered.emit({"correct": false})

func _show_feedback_text_for_note(midi_note: int, text: String, color: Color):
	pass

# ============================================================
# REWARD SYSTEM
# ============================================================

func _play_reward_song(semitones: int, mode: IntervalMode) -> float:
	# 1. Get Riffs from RiffManager (Includes Built-ins and User Riffs)
	if not GameManager.has_node("RiffManager"):
		print("[QuizManager] RiffManager not found!")
		return 0.0
		
	var rm = GameManager.get_node("RiffManager")
	var candidates = rm.get_riffs_for_interval(semitones)
	
	if candidates.is_empty():
		return 0.0
		
	# 2. Pick Winner
	var winner = candidates.pick_random()
	print("[QuizManager] Playing Reward: %s (%s)" % [winner.get("title", "Untitled"), winner.get("source", "unknown")])
	
	# 3. Play
	var notes = winner.get("notes", [])
	var duration = 0.0
	
	if winner.get("source") == "builtin":
		if winner.has("motif"):
			duration = _play_builtin_motif(winner.motif)
		else:
			duration = _play_riff_snippet(notes)
	else:
		# User Riff (Free Timing)
		duration = _play_riff_snippet(notes)
		
	return duration

# Playback Control
var _current_playback_id: int = 0
var _is_processing_correct_answer: bool = false

func _stop_playback():
	print("[QuizManager] Stopping Playback. ID: %d -> %d" % [_current_playback_id, _current_playback_id + 1])
	_current_playback_id += 1 # Invalidate pending callbacks
	_clear_root_highlight()
		
	AudioEngine.stop_all_notes() # Kill ringing sounds immediately
	
	# Clear any active visuals on fretboard
	EventBus.visual_note_off.emit(-1, -1) # Send "Clear All" signal (Convention: -1)

func _play_riff_snippet(notes: Array) -> float:
	if notes.is_empty(): return 0.0
	
	var my_id = _current_playback_id
	print("[QuizManager] Starting Riff Snippet. Playback ID: %d" % my_id)
	
	# 1. Calculate Anchor / Transposition Logic
	var first_ms = notes[0].start_ms
	var first_note_orig = notes[0].pitch
	var first_string_orig = notes[0].get("string", 0)
	
	var transpose_delta = interval_root_note - first_note_orig
	
	# Determine Target Anchor Pitch
	var target_anchor_pitch = first_note_orig + transpose_delta
	while target_anchor_pitch < 40: target_anchor_pitch += 12
	while target_anchor_pitch > 84: target_anchor_pitch -= 12
	
	# Determine Optimal String for Anchor
	var target_anchor_pos = _find_valid_pos_for_note(target_anchor_pitch, GameManager.player_fret)
	var target_anchor_string = target_anchor_pos.string if target_anchor_pos.valid else 0
	
	var string_shift = target_anchor_string - first_string_orig
	
	var max_end_time = 0.0
	
	for n in notes:
		var delay = (n.start_ms - first_ms) / 1000.0
		var dur = n.duration_ms / 1000.0
		var note_end = delay + dur
		if note_end > max_end_time: max_end_time = note_end
		
		# Pitch Calculation
		var pitch = n.pitch + transpose_delta
		while pitch < 40: pitch += 12
		while pitch > 84: pitch -= 12
		
		# String Calculation
		var orig_string = n.get("string", 0)
		var proposed_string = orig_string + string_shift
		var final_string = 0
		var valid_shape = false
		if proposed_string >= 0 and proposed_string <= 5:
			var open_notes = [40, 45, 50, 55, 59, 64]
			var fret = pitch - open_notes[proposed_string]
			if fret >= 0 and fret <= 19:
				final_string = proposed_string
				valid_shape = true
		if not valid_shape:
			var fallback = _find_valid_pos_for_note(pitch, GameManager.player_fret)
			final_string = fallback.string if fallback.valid else 0
			
		# Schedule Note
		get_tree().create_timer(delay).timeout.connect(func():
			if _current_playback_id != my_id: return
			
			AudioEngine.play_note(pitch)
			EventBus.visual_note_on.emit(pitch, final_string)
			
			get_tree().create_timer(dur).timeout.connect(func():
				# We don't strictly need ID check for off, but safer
				if _current_playback_id != my_id: return
				EventBus.visual_note_off.emit(pitch, final_string)
			)
		)
		
	return max_end_time

func _play_builtin_motif(relative_notes: Array) -> float:
	var my_id = _current_playback_id
	var delay = 0.0
	var step = 0.4
	
	for rel in relative_notes:
		var pitch = interval_root_note + rel
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _current_playback_id != my_id: return
			AudioEngine.play_note(pitch)
			EventBus.visual_note_on.emit(pitch, 0)
			get_tree().create_timer(step * 0.8).timeout.connect(func():
				if _current_playback_id != my_id: return
				EventBus.visual_note_off.emit(pitch, 0)
			)
		)
		delay += step
		
	return delay + (step * 0.8)
