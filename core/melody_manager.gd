class_name MelodyManager
extends Node

# ============================================================
# SIGNALS
# ============================================================
signal recording_started
signal recording_stopped
signal visual_note_on(midi_note: int, string_idx: int) # For Fretboard Flash
signal visual_note_off(midi_note: int, string_idx: int)

# ============================================================
# CONSTANTS & SETTINGS
# ============================================================
const QUANTIZE_GRID = 0.25 # 16th note grid (0.25 of a quarter note beat)

# ============================================================
# STATE
# ============================================================
var is_recording: bool = false
var recorded_notes: Array[Dictionary] = [] # {pitch, string, start_beat, duration}
var active_notes: Dictionary = {} # { pitch_string_key: {start_time, ...} } - For tracking held notes

# Playback State
var _last_beat_time: float = -1.0
var _active_visuals: Dictionary = {} # { note_ref: true }

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	# Connect to EventBus
	EventBus.beat_updated.connect(_on_beat_updated)
	EventBus.sequencer_stopped.connect(_on_sequencer_stopped)
	EventBus.tile_pressed.connect(_on_tile_pressed)
	EventBus.tile_released.connect(_on_tile_released)

func _on_sequencer_stopped() -> void:
	if is_recording:
		stop_recording()
	_last_beat_time = -1.0
	_release_all_visuals()

func _on_beat_updated(_current_beat: int, _total_beats: int) -> void:
	# This is the coarse beat update (quarter notes)
	pass

# ============================================================
# RECORDING LOGIC
# ============================================================
func start_recording() -> void:
	if not _get_sequencer(): return
	is_recording = true
	recording_started.emit()
	print("[MelodyManager] Recording Started")

func stop_recording() -> void:
	is_recording = false
	active_notes.clear()
	recording_stopped.emit()
	print("[MelodyManager] Recording Stopped. Total Notes: ", recorded_notes.size())
	# Persistence todo

func toggle_recording() -> void:
	if is_recording:
		stop_recording()
	else:
		start_recording()

func clear_melody() -> void:
	recorded_notes.clear()
	active_notes.clear()
	print("[MelodyManager] Melody Cleared")

func undo_last_note() -> void:
	if recorded_notes.size() > 0:
		var removed = recorded_notes.pop_back()
		print("[MelodyManager] Undo note at beat %.2f" % removed.start_beat)
		# Provide some feedback? Signal?
	else:
		print("[MelodyManager] Nothing to undo")

func quantize_notes(grid: float = QUANTIZE_GRID) -> void:
	if recorded_notes.is_empty(): return
	
	var count = 0
	for note in recorded_notes:
		var orig_start = note.start_beat
		var orig_dur = note.duration
		
		# Snap Start
		note.start_beat = roundf(orig_start / grid) * grid
		
		# Snap Duration (min grid)
		note.duration = maxf(roundf(orig_dur / grid) * grid, grid)
		
		if note.start_beat != orig_start or note.duration != orig_dur:
			count += 1
			
	print("[MelodyManager] Quantized %d notes to grid %.2f" % [count, grid])

# ============================================================
# INPUT HANDLING (RECORDING)
# ============================================================
func _on_tile_pressed(midi_note: int, string_index: int) -> void:
	if not is_recording: return
	
	var seq = _get_sequencer()
	if not seq or not seq.is_playing: return
	
	var state = seq.get_playback_state()
	var now = Time.get_ticks_msec()
	var elapsed_ms = now - state.last_beat_time
	var beat_duration_ms = (60.0 / state.bpm) * 1000.0
	var offset_beat = clampf(elapsed_ms / beat_duration_ms, 0.0, 1.0)
	
	var start_beat_global = float(state.beat) + offset_beat
	
	# Quantize Start (Snap to nearest 0.25)
	var snapped_beat = roundf(start_beat_global / QUANTIZE_GRID) * QUANTIZE_GRID
	
	var note_key = "%d_%d" % [midi_note, string_index]
	active_notes[note_key] = {
		"step": state.step,
		"start_beat": snapped_beat,
		"raw_start_ms": now,
		"pitch": midi_note,
		"string": string_index
	}
	
	# Visual Feedback (Immediate)
	visual_note_on.emit(midi_note, string_index)
	# Play Audio (Directly)
	AudioEngine.play_note(midi_note)

func _on_tile_released(midi_note: int, string_index: int) -> void:
	if not is_recording: return
	
	var note_key = "%d_%d" % [midi_note, string_index]
	if not active_notes.has(note_key): return
	
	var start_data = active_notes[note_key]
	active_notes.erase(note_key)
	
	var seq = _get_sequencer()
	if not seq: return
	var state = seq.get_playback_state()
	
	# Calculate Duration
	var bpm = state.bpm
	var beat_ms = (60.0 / bpm) * 1000.0
	var now = Time.get_ticks_msec()
	var duration_beat = (now - start_data.raw_start_ms) / beat_ms
	
	# Quantize Duration (Min 0.25)
	var snapped_dur = maxf(roundf(duration_beat / QUANTIZE_GRID) * QUANTIZE_GRID, QUANTIZE_GRID)
	
	var new_note = {
		"step": start_data.step,
		"start_beat": start_data.start_beat,
		"duration": snapped_dur,
		"pitch": midi_note,
		"string": string_index
	}
	
	recorded_notes.append(new_note)
	visual_note_off.emit(midi_note, string_index)

# ============================================================
# PLAYBACK LOGIC (GHOST NOTES)
# ============================================================
func _process(_delta: float) -> void:
	if not EventBus.is_sequencer_playing:
		return
		
	var seq = _get_sequencer()
	if not seq: return
	var state = seq.get_playback_state()
	
	var beat_ms = (60.0 / state.bpm) * 1000.0
	var elapsed = Time.get_ticks_msec() - state.last_beat_time
	var current_sub_beat = float(state.beat) + (elapsed / beat_ms)
	
	# Check all notes
	# Optimization: Could filter by step first
	for note in recorded_notes:
		if note.step == state.step:
			# Check Start
			var diff = current_sub_beat - note.start_beat
			# Trigger logic: within a small window AND not already active?
			# Actually, if we just check "is inside duration", we can maintain state.
			if diff >= 0 and diff < note.duration:
				_trigger_visual_note(note)
			else:
				_release_visual_note(note)
		else:
			_release_visual_note(note)

func _trigger_visual_note(note: Dictionary) -> void:
	if not _active_visuals.has(note):
		_active_visuals[note] = true
		visual_note_on.emit(note.pitch, note.string)
		AudioEngine.play_note(note.pitch)

func _release_visual_note(note: Dictionary) -> void:
	if _active_visuals.has(note):
		_active_visuals.erase(note)
		visual_note_off.emit(note.pitch, note.string)

func _release_all_visuals() -> void:
	for note in _active_visuals.keys():
		visual_note_off.emit(note.pitch, note.string)
	_active_visuals.clear()

# ============================================================
# HELPERS
# ============================================================
func _get_sequencer() -> Node:
	var seqs = get_tree().get_nodes_in_group("sequencer")
	if seqs.size() > 0: return seqs[0]
	return null
