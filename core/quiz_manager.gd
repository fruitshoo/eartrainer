extends Node

# ============================================================
# SIGNALS
# ============================================================
signal quiz_started(data: Dictionary) # { "type": "note"|"interval", ... }
signal quiz_answered(result: Dictionary) # { "correct": bool, "answer": ..., "target": ... }

# ============================================================
# ENUMS
# ============================================================
enum QuizType {NONE, NOTE_LOCATION, INTERVAL, PITCH_CLASS, CHORD_QUALITY}
enum IntervalMode {ASCENDING, DESCENDING, HARMONIC}

# ============================================================
# STATE
# ============================================================
var current_quiz_type: QuizType = QuizType.NONE

# -- State Sync (Used by handlers/playback) --
var current_target_note: int = -1
var interval_root_note: int = -1
var interval_target_note: int = -1
var interval_semitones: int = 0
var current_interval_mode: int = 0 # 0=Asc, 1=Desc, 2=Harmonic
var pitch_target_class: int = -1
var pitch_target_note_actual: int = -1
var chord_target_type: String = ""
var _current_root_fret: int = -1

# -- Settings (Accessed by Handlers) --
var active_modes: Array = [IntervalMode.ASCENDING]
var active_intervals: Array = [0, 2, 4, 5, 7, 9, 11, 12]
var active_pitch_classes: Array = [0, 2, 4, 5, 7, 9, 11]
var active_chord_types: Array = ["maj", "min"]
var chord_root_mode: String = "fixed"
var chord_fixed_root: int = 60

# -- Handler Strategy --
var _handlers: Dictionary = {}
var _active_handler: BaseQuizHandler = null

# ============================================================
# LIFECYCLE
# ============================================================
func _ready():
	EventBus.tile_clicked.connect(_on_tile_clicked)
	_init_handlers()

func _init_handlers():
	_handlers = {
		QuizType.PITCH_CLASS: PitchQuizHandler.new(self),
		QuizType.CHORD_QUALITY: ChordQuizHandler.new(self),
		QuizType.INTERVAL: IntervalQuizHandler.new(self),
		QuizType.NOTE_LOCATION: NoteQuizHandler.new(self)
	}

func _on_tile_clicked(note: int, string_idx: int, _modifiers: Dictionary):
	if AudioEngine:
		AudioEngine.play_note(note, string_idx)

	# Dispatch to active handler
	if _active_handler:
		_active_handler.on_tile_clicked(note, string_idx)

# ============================================================
# CORE FUNCTIONS
# ============================================================

# State for restoring visuals
var _saved_visual_settings: Dictionary = {}

func _switch_to_handler(type: QuizType) -> BaseQuizHandler:
	_stop_playback()
	_clear_markers()
	
	current_quiz_type = type
	_active_handler = _handlers.get(type)
	return _active_handler

func start_pitch_quiz():
	var h = _switch_to_handler(QuizType.PITCH_CLASS)
	if h: h.start_quiz()

func check_pitch_answer(clicked_note: int, string_idx: int):
	if _active_handler and current_quiz_type == QuizType.PITCH_CLASS:
		_active_handler.on_tile_clicked(clicked_note, string_idx)

func start_chord_quiz():
	var h = _switch_to_handler(QuizType.CHORD_QUALITY)
	if h: h.start_quiz()

func check_chord_answer(start_type: String):
	if _active_handler and current_quiz_type == QuizType.CHORD_QUALITY:
		_active_handler.check_answer(start_type)

func start_note_quiz():
	var h = _switch_to_handler(QuizType.NOTE_LOCATION)
	if h: h.start_quiz()

func check_note_answer(clicked_note: int):
	if _active_handler and current_quiz_type == QuizType.NOTE_LOCATION:
		_active_handler.check_answer(clicked_note)

func start_interval_quiz():
	var h = _switch_to_handler(QuizType.INTERVAL)
	if h: h.start_quiz()

func check_interval_answer_with_tile(note: int, string_idx: int):
	if _active_handler and current_quiz_type == QuizType.INTERVAL:
		_active_handler.on_tile_clicked(note, string_idx)

func _auto_hide_visuals():
	if _saved_visual_settings.is_empty():
		_saved_visual_settings = {
			"root": GameManager.highlight_root,
			"chord": GameManager.highlight_chord,
			"scale": GameManager.highlight_scale
		}
		# Disable all
		GameManager.highlight_root = false
		GameManager.highlight_chord = false
		GameManager.highlight_scale = false
		GameManager.settings_changed.emit() # Force update

# ============================================================
# UTILITIES
# ============================================================
func stop_quiz():
	current_quiz_type = QuizType.NONE
	_clear_markers()
	
	# [New] Restore Visual Settings
	if not _saved_visual_settings.is_empty():
		GameManager.highlight_root = _saved_visual_settings.get("root", true)
		GameManager.highlight_chord = _saved_visual_settings.get("chord", true)
		GameManager.highlight_scale = _saved_visual_settings.get("scale", true)
		GameManager.settings_changed.emit() # Force update
		_saved_visual_settings.clear()
		
	print("[QuizManager] Quiz Stopped.")

# start_note_quiz / check_note_answer removed, logic moved to NoteQuizHandler.gd


# ============================================================
# INTERVAL QUIZ LOGIC
# ============================================================

# start_interval_quiz removed, logic moved to IntervalQuizHandler.gd

# _play_chord_structure removed, moved to ChordQuizHandler.gd

# _pick_fallback_question removed, logic moved to IntervalQuizHandler.gd

var _active_markers: Array = [] # List of tiles with active markers

# Helper to find a valid string/fret for a given MIDI note
# Prioritizes positions close to preferred_fret (defaults to player_fret)
func _find_valid_pos_for_note(midi_note: int, preferred_fret: int = -1) -> Dictionary:
	if preferred_fret == -1:
		preferred_fret = GameManager.player_fret
		
	var candidates = []
	var open_notes = [40, 45, 50, 55, 59, 64] # Index 0 to 5
	
	for s_idx in range(6):
		var fret = midi_note - open_notes[s_idx]
		# [Fix] Verify tile actually exists (Max Fret is usually 12, not 19)
		if fret >= 0 and GameManager.find_tile(s_idx, fret):
			var dist = abs(fret - preferred_fret)
			candidates.append({"valid": true, "string": s_idx, "fret": fret, "dist": dist})
			
	if candidates.is_empty():
		return {"valid": false, "string": - 1, "fret": - 1}
		
	# Sort by distance to preferred fret
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	
	return candidates[0]

func _highlight_tile(string_idx: int, fret_idx: int, color: Color):
	var tile = GameManager.find_tile(string_idx, fret_idx)
	if tile and tile.has_method("set_marker"):
		tile.set_marker(color, 1.0) # Reduced energy from 2.0 to 1.0 for Magenta compat
		if not tile in _active_markers:
			_active_markers.append(tile)
		
	# Also ensure camera follows if needed? No, leave camera to user or GameManager logic.
	# But ensure this tile is the one used for the visual anchor.

func _clear_markers():
	for tile in _active_markers:
		if is_instance_valid(tile) and tile.has_method("clear_marker"):
			tile.clear_marker()
	_active_markers.clear()

func play_current_interval():
	# Replay the current interval/note
	_stop_playback() # Stop any ringing first
	_play_quiz_sound(current_quiz_type)

func _play_note_with_blink(note: int, duration: float = 0.3, force_visual: bool = true):
	# Play Audio
	AudioEngine.play_note(note)
	
	# Determine if we should show visual
	# 1. If 'force_visual' is true (e.g. Root note, or Pitch Quiz), always show.
	# 2. If 'force_visual' is false (e.g. Target note), show only if 'show_target_visual' is true.
	var should_show = force_visual or GameManager.show_target_visual
	
	if not should_show:
		return # Audio only
	
	# Find best visual target (prioritize active markers)
	var string_idx = -1
	
	for tile in _active_markers:
		if is_instance_valid(tile) and tile.midi_note == note:
			string_idx = tile.string_index
			break
			
	if string_idx == -1:
		# Fallback search
		var pos = _find_valid_pos_for_note(note, _current_root_fret)
		string_idx = pos.string if pos.valid else 0
		
	# Emit Visual Flash (Magenta via GameManager)
	EventBus.visual_note_on.emit(note, string_idx)
	
	# Schedule Off
	var my_id = _current_playback_id
	get_tree().create_timer(duration).timeout.connect(func():
		if _current_playback_id != my_id: return
		EventBus.visual_note_off.emit(note, string_idx)
	)

func _play_quiz_sound(type: QuizType):
	var my_id = _current_playback_id
	
	if type == QuizType.PITCH_CLASS:
		_play_note_with_blink(pitch_target_note_actual)
		return
		
	if type == QuizType.CHORD_QUALITY:
		if _active_handler and _active_handler.has_method("_play_chord_structure"):
			_active_handler.call("_play_chord_structure", interval_root_note, chord_target_type)
		return

	# Pulse the root visual again when playing? (Optional now that we blink)
	# for tile in _active_markers: ... (Removed to avoid clutter, blinking is enough)
	
	# Note: Root is always forced (force_visual=true). Target is conditional (force_visual=false).
	
	if current_interval_mode == IntervalMode.HARMONIC:
		_play_note_with_blink(interval_root_note, 1.0, true)
		_play_note_with_blink(interval_target_note, 1.0, false)
	elif current_interval_mode == IntervalMode.DESCENDING:
		_play_note_with_blink(interval_root_note, 0.6, true)
		
		get_tree().create_timer(0.6).timeout.connect(func():
			if _current_playback_id != my_id: return
			_play_note_with_blink(interval_target_note, 1.0, false)
		)
	else: # ASCENDING
		_play_note_with_blink(interval_root_note, 0.6, true)
		
		get_tree().create_timer(0.6).timeout.connect(func():
			if _current_playback_id != my_id: return
			_play_note_with_blink(interval_target_note, 1.0, false)
		)

# check_interval_answer removed - was unused legacy code

# check_interval_answer_with_tile removed, moved to IntervalQuizHandler.gd

# _show_feedback_text_for_note removed - was unimplemented

# ============================================================
# REWARD SYSTEM
# ============================================================

func _play_reward_song(key: int, mode: int) -> float:
	var type = "interval"
	if current_quiz_type == QuizType.PITCH_CLASS:
		type = "pitch"
		
	# Find a riff for this key/type
	if not GameManager.has_node("RiffManager"):
		print("[QuizManager] RiffManager not found!")
		return 0.0
		
	# 2. Pick Winner based on Preference
	var rm = GameManager.get_node("RiffManager")
	var candidates = rm.get_riffs(key, type, mode)
	
	if candidates.is_empty():
		print("No reward riff found for key %d (%s)" % [key, type])
		return 0.5 # Default tiny wait

	var pref = rm.get_playback_preference(key, type)
	var winner = {}
	
	if pref.get("mode") == "single" and not pref.get("id", "").is_empty():
		var target_id = pref["id"]
		for cand in candidates:
			if cand.get("id") == target_id:
				winner = cand
				break
		if winner.is_empty():
			print("[QuizManager] Preferred riff not found, falling back to random.")
			winner = candidates.pick_random()
	else:
		winner = candidates.pick_random()
		
	print("[QuizManager] Playing Reward: %s (%s)" % [winner.get("title", "Untitled"), winner.get("source", "unknown")])
	
	# 3. Play
	# 3. Play
	var duration = 0.0
	
	if winner.get("source") == "builtin":
		# Builtin riffs now also use "notes" format (converted in RiffManager)
		# So we can just use _play_riff_snippet for all
		duration = _play_riff_snippet(winner)
	else:
		# User Riff (Free Timing)
		duration = _play_riff_snippet(winner)
		
	return duration

# Playback Control
var _current_playback_id: int = 0
var _is_processing_correct_answer: bool = false

func _stop_playback():
	print("[QuizManager] Stopping Playback. ID: %d -> %d" % [_current_playback_id, _current_playback_id + 1])
	_is_processing_correct_answer = false # Reset input lock
	# elif block removed - erroneous placement
	
	_current_playback_id += 1 # Invalidate pending callbacks
	# _clear_root_highlight() # Keep visual hint during playback stops
		
	AudioEngine.stop_all_notes() # Kill ringing sounds immediately
	
	# Clear any active visuals on fretboard
	EventBus.visual_note_off.emit(-1, -1) # Send "Clear All" signal (Convention: -1)

# Public wrapper for previewing riffs (e.g. from Example Manager)
func play_riff_preview(riff_data: Dictionary) -> void:
	_stop_playback()
	_play_riff_snippet(riff_data)

func _play_riff_snippet(riff_data: Dictionary) -> float:
	var notes = riff_data.get("notes", [])
	var slots = riff_data.get("slots", [])
	var bpm = int(riff_data.get("bpm", 120))
	
	if notes.is_empty(): return 0.0
	
	var my_id = _current_playback_id
	print("[QuizManager] Starting Riff Snippet (ID: %d). BPM: %d, Slots: %d" % [my_id, bpm, slots.size()])
	
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
	var anchor_fret = _current_root_fret if _current_root_fret != -1 else GameManager.player_fret
	var target_anchor_pos = _find_valid_pos_for_note(target_anchor_pitch, anchor_fret)
	var target_anchor_string = target_anchor_pos.string if target_anchor_pos.valid else 0
	
	var string_shift = target_anchor_string - first_string_orig
	
	var max_end_time = 0.0
	
	# 2. Schedule Melody
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
			var fallback_fret = _current_root_fret if _current_root_fret != -1 else GameManager.player_fret
			var fallback = _find_valid_pos_for_note(pitch, fallback_fret)
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

	# 3. Schedule Chords (Backing Track)
	# Assuming slots start from time 0 (relative to melody Start? Or Song Start?)
	# Generally Melody Start_MS is absolute from Song Start.
	# So we can calculate Beat Times.
	# Beat Duration = 60 / BPM
	
	if not slots.is_empty():
		var spb = 60.0 / bpm # Seconds per beat
		# We need to sync slots to the Melody's "Relative Zero".
		# But Slots are absolute (Bar 1, 2...). Melody notes are absolute (ms).
		# We should just play them using their absolute times, shifted by `first_ms` so they align.
		# Note: We only want to play the chords that OVERLAP with the melody snippet.
		
		var current_beat = 0.0
		# Standard: 4/4 assume? ProgressionManager default is 4/4 usually.
		# But slots don't have explicit duration in the struct. `ProgressionManager` infers it from density.
		# We stored `slots` as raw array. We need to infer beats per slot.
		# For simplicity, assume 4 beats per bar, 1 slot per bar = 4 beats. 2 slots = 2 beats.
		# But `RiffManager` didn't save `bar_densities`.
		# Fallback: Assume 1 slot = 4 beats (Whole note) or 2 beats? 
		# Most songs are 4 beats/slot if density is 1.
		
		# Better approach: Just play them as 4-beat chords for now.
		# Or update RiffManager to save `bar_densities`.
		
		# Let's check RiffManager import again. I didn't save densities.
		# Just assume 1 Slot = 4 Beats for MVP.
		var beats_per_slot = 4.0
		
		for i in range(slots.size()):
			var slot = slots[i]
			if slot == null or slot.is_empty():
				current_beat += beats_per_slot
				continue
				
			var slot_start_sec = current_beat * spb
			var slot_dur_sec = beats_per_slot * spb
			
			# Align: Melody starts at `first_ms`.
			# If chord starts before melody, we might skip or play partial?
			# Actually, we want to play the chords relative to the melody.
			# If melody starts at 5.0s, and we play back, we effectively shift melody to 0.0s delay.
			# So we should shift chords too: `play_time = slot_start - (first_ms / 1000.0)`
			
			var playback_delay = slot_start_sec - (first_ms / 1000.0)
			
			# Only play if it overlaps reasonable range (e.g. not 10 seconds before melody)
			if playback_delay + slot_dur_sec > 0 and playback_delay < max_end_time:
				# Transpose Chord Root
				var root = slot.get("root", 0)
				var type = slot.get("type", "")
				var transposed_root = root + transpose_delta
				
				# Schedule Chord
				# Ensure positive delay (if chord started before melody, play immediately)
				var final_delay = max(0.0, playback_delay)
				var final_dur = slot_dur_sec # (Simplify cut-off)
				if final_dur > 0: pass # Suppress unused warning
				
				get_tree().create_timer(final_delay).timeout.connect(func():
					if _current_playback_id != my_id: return
					# Play Chord (Arpeggio or Strum)
					# Helper needed: _play_chord_structure(root, type) is for Quiz.
					# Maybe expose AudioEngine.play_chord?
					# For now, rapid strum manually:
					var chord_intervals = ChordQuizData.get_chord_intervals(type)
					for k in range(chord_intervals.size()):
						var n_pitch = transposed_root + chord_intervals[k]
						# Keep in range?
						while n_pitch < 40: n_pitch += 12
						while n_pitch > 76: n_pitch -= 12 # Keep chords lower/comping
						
						AudioEngine.play_note(n_pitch)
						# No visual for backing chords to avoid confusion?
				)
			
			current_beat += beats_per_slot
		
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
