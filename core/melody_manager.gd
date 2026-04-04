class_name MelodyManager
extends Node

const MELODY_MANAGER_GRID = preload("res://core/melody_manager_grid.gd")
const MELODY_MANAGER_RECORDING = preload("res://core/melody_manager_recording.gd")

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
var _grid_helper: MelodyManagerGrid
var _recording_helper: MelodyManagerRecording

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_grid_helper = MELODY_MANAGER_GRID.new(self)
	_recording_helper = MELODY_MANAGER_RECORDING.new(self)
	# Connect to EventBus
	EventBus.sequencer_stopped.connect(_on_sequencer_stopped)
	EventBus.tile_pressed.connect(_on_tile_pressed)
	EventBus.tile_released.connect(_on_tile_released)

func _on_sequencer_stopped() -> void:
	_recording_helper.on_sequencer_stopped()

# ============================================================
# RECORDING LOGIC
# ============================================================
func start_recording() -> void:
	_recording_helper.start_recording()

func stop_recording() -> void:
	_recording_helper.stop_recording()

func toggle_recording() -> void:
	_recording_helper.toggle_recording()

func clear_melody() -> void:
	_grid_helper.clear_melody()

func undo_last_note() -> void:
	_grid_helper.undo_last_note()

func quantize_notes(grid: float = QUANTIZE_GRID) -> void:
	_grid_helper.quantize_notes(grid)

func import_recorded_notes(notes: Array) -> void:
	_grid_helper.import_recorded_notes(notes)

func sync_from_progression() -> void:
	_grid_helper.sync_from_progression()

# ============================================================
# INPUT HANDLING (RECORDING)
# ============================================================
func _on_tile_pressed(midi_note: int, string_index: int) -> void:
	_recording_helper.on_tile_pressed(midi_note, string_index)

func _on_tile_released(midi_note: int, string_index: int) -> void:
	_recording_helper.on_tile_released(midi_note, string_index)

# ============================================================
# PLAYBACK LOGIC
# ============================================================
func _process(_delta: float) -> void:
	return

func _trigger_visual_note(note: Dictionary) -> void:
	if not _active_visuals.has(note):
		_active_visuals[note] = true
		visual_note_on.emit(note.pitch, note.string)
		AudioEngine.play_note(note.pitch, note.string)

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
func _find_last_anchor_note() -> Dictionary:
	return _grid_helper.find_last_anchor_note()

func _clear_note_chain(bar: int, beat: int, sub: int, note_data: Dictionary) -> void:
	_grid_helper.clear_note_chain(bar, beat, sub, note_data)

func _extract_recorded_notes_from_progression() -> Array[Dictionary]:
	return _grid_helper.extract_recorded_notes_from_progression()

func _build_melody_events_from_recorded_notes(notes: Array[Dictionary]) -> Dictionary:
	return _grid_helper.build_melody_events_from_recorded_notes(notes)

func _recorded_note_to_position(note: Dictionary) -> Dictionary:
	return _grid_helper.recorded_note_to_position(note)

func _position_to_recorded_time(bar: int, beat: int, sub: int) -> Dictionary:
	return _grid_helper.position_to_recorded_time(bar, beat, sub)

func _advance_position(bar: int, beat: int, sub: int) -> Dictionary:
	return _grid_helper.advance_position(bar, beat, sub)

func _set_event(target: Dictionary, bar: int, beat: int, sub: int, note_data: Dictionary) -> void:
	_grid_helper.set_event(target, bar, beat, sub, note_data)

func _melody_key_order(key: String) -> int:
	return _grid_helper.melody_key_order(key)

func _get_sequencer() -> Node:
	return _recording_helper.get_sequencer()
