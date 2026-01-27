class_name RiffEditor
extends Control

signal closed

# ============================================================
# NODES
# ============================================================
@onready var title_input: LineEdit = %TitleInput
@onready var riff_list: ItemList = %RiffList
@onready var record_btn: Button = %RecordButton
@onready var play_btn: Button = %PlayButton
@onready var delete_btn: Button = %DeleteButton
@onready var save_btn: Button = %SaveButton
@onready var cancel_btn: Button = %CancelButton
@onready var status_label: Label = %StatusLabel
@onready var notes_container: Control = %NotesVisual # Placeholder for piano roll

@onready var editor_panel: Control = $EditorPanel
@onready var background_dim: Control = $BackgroundDim
@onready var recording_overlay: Control = %RecordingOverlay
@onready var stop_rec_btn: Button = %StopRecButton

# ============================================================
# STATE
# ============================================================
var target_interval: int = 4 # Default Major 3rd
var current_riffs: Array = []
var selected_riff_index: int = -1

# Recording State
var is_recording: bool = false
var recorded_notes: Array = [] # [{pitch, string, start_ms, duration_ms}]
var recording_start_time: int = 0
var active_held_notes: Dictionary = {} # { key: {start_ms, pitch, string} }

# Dragging State
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# ============================================================
# LIFECYCLE
# ============================================================
func _ready():
	_connect_signals()
	_refresh_list()
	_update_ui_state()
	
	# Global Input Hook for Recording
	EventBus.tile_pressed.connect(_on_tile_pressed)
	EventBus.tile_released.connect(_on_tile_released)
	
	# Draggable Window
	$EditorPanel.gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = $EditorPanel.get_global_mouse_position() - $EditorPanel.global_position
			else:
				is_dragging = false
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			$EditorPanel.global_position = $EditorPanel.get_global_mouse_position() - drag_offset

func setup(interval: int):
	target_interval = interval
	var interval_name = IntervalQuizData.INTERVALS.get(interval, {"name": "Unknown"}).name
	$EditorPanel/TitleLabel.text = "Manage Riffs - %s (%d Semitones)" % [interval_name, interval]
	_refresh_list()

func _connect_signals():
	title_input.text_changed.connect(func(_t): _update_ui_state())
	riff_list.item_selected.connect(_on_list_item_selected)
	
	record_btn.pressed.connect(_toggle_recording)
	play_btn.pressed.connect(_play_preview)
	delete_btn.pressed.connect(_delete_selected)
	
	save_btn.pressed.connect(_save_current)
	cancel_btn.pressed.connect(func():
		if is_recording: _stop_recording()
		closed.emit()
		queue_free()
	)
	stop_rec_btn.pressed.connect(_stop_recording)

# ============================================================
# RECORDING LOGIC (Free Timing)
# ============================================================
func _toggle_recording():
	if is_recording:
		_stop_recording()
	else:
		_start_recording()

func _start_recording():
	is_recording = true
	recorded_notes.clear()
	active_held_notes.clear()
	recording_start_time = Time.get_ticks_msec()
	
	# Switch Mode
	editor_panel.visible = false
	background_dim.visible = false
	recording_overlay.visible = true
	
	# Allow clicks to pass through to game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	status_label.text = "Recording... Play on the fretboard!"
	
func _stop_recording():
	is_recording = false
	active_held_notes.clear() # Force close any stuck notes
	
	print("[RiffEditor] Stopped. Captured: ", recorded_notes.size(), " notes.")
	print("[RiffEditor] Notes: ", recorded_notes)
	
	# Restore Mode
	editor_panel.visible = true
	background_dim.visible = true
	recording_overlay.visible = false
	
	# Block clicks again
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	record_btn.text = "Record (Input)"
	record_btn.modulate = Color.WHITE
	status_label.text = "Recording finished. %d notes captured." % recorded_notes.size()
	
	# Normalize timing (start from 0)
	if not recorded_notes.is_empty():
		var first_start = recorded_notes[0].start_ms
		for note in recorded_notes:
			note.start_ms -= first_start
			
	_update_ui_state()

func _on_tile_pressed(midi: int, string_idx: int):
	if not is_recording: return
	
	print("[RiffEditor] Note Pressed: ", midi)
	var now = Time.get_ticks_msec()
	var key = "%d_%d" % [midi, string_idx]
	
	active_held_notes[key] = {
		"pitch": midi,
		"string": string_idx,
		"start_ms": now
	}
	
	# Visual Feedback?
	AudioEngine.play_note(midi)

func _on_tile_released(midi: int, string_idx: int):
	if not is_recording: return
	
	print("[RiffEditor] Note Released: ", midi)
	var key = "%d_%d" % [midi, string_idx]
	if active_held_notes.has(key):
		var data = active_held_notes[key]
		var now = Time.get_ticks_msec()
		var duration = now - data.start_ms
		
		var note_entry = {
			"pitch": midi,
			"string": string_idx,
			"start_ms": data.start_ms - recording_start_time, # Relative to rec start
			"duration_ms": duration
		}
		recorded_notes.append(note_entry)
		active_held_notes.erase(key)

# ============================================================
# PLAYBACK LOGIC
# ============================================================
func _play_preview():
	if recorded_notes.is_empty(): return
	
	status_label.text = "Playing preview..."
	for note in recorded_notes:
		var delay_sec = note.start_ms / 1000.0
		var dur_sec = note.duration_ms / 1000.0
		
		get_tree().create_timer(delay_sec).timeout.connect(func():
			AudioEngine.play_note(note.pitch)
			EventBus.visual_note_on.emit(note.pitch, note.string)
			
			get_tree().create_timer(dur_sec).timeout.connect(func():
				EventBus.visual_note_off.emit(note.pitch, note.string)
			)
		)

# ============================================================
# DATA MANAGEMENT
# ============================================================
func _refresh_list():
	riff_list.clear()
	var rm = GameManager.get_node("RiffManager")
	current_riffs = rm.get_riffs_for_interval(target_interval)
	
	for i in range(current_riffs.size()):
		var riff = current_riffs[i]
		var title = riff.get("title", "Untitled")
		var source = riff.get("source", "user")
		var label = "%s (%s)" % [title, source]
		riff_list.add_item(label)
		# Lock builtin?
		if source == "builtin":
			riff_list.set_item_metadata(i, {"locked": true})
			# riff_list.set_item_icon(i, load("res://assets/icons/lock.png")) # Icon missing
			label += " [Locked]" # Fallback text indicator
			
	_clear_editor()

func _on_list_item_selected(index: int):
	selected_riff_index = index
	var riff = current_riffs[index]
	
	title_input.text = riff.get("title", "")
	recorded_notes = riff.get("notes", []).duplicate(true)
	
	var is_locked = (riff.get("source") == "builtin")
	title_input.editable = !is_locked
	record_btn.disabled = is_locked
	delete_btn.disabled = is_locked
	save_btn.disabled = is_locked # Saving overwrites? Or creates new?
	
	_update_ui_state()

func _clear_editor():
	selected_riff_index = -1
	title_input.text = ""
	recorded_notes.clear()
	_update_ui_state()

func _update_ui_state():
	var has_notes = not recorded_notes.is_empty()
	var has_title = not title_input.text.strip_edges().is_empty()
	var is_selected = selected_riff_index != -1
	var is_locked = false
	if is_selected:
		var riff = current_riffs[selected_riff_index]
		is_locked = (riff.get("source") == "builtin")
	
	# target_interval unused warning fix
	if target_interval < 0: pass
	
	play_btn.disabled = not has_notes
	
	# Save conditions: Must have title, notes, and NOT be locked existing item (unless we implement Save As Copy)
	# For simplicity: If locked, Save creates NEW. If user, Save OVERWRITES.
	save_btn.disabled = not (has_notes and has_title)

func _delete_selected():
	if selected_riff_index == -1: return
	var riff = current_riffs[selected_riff_index]
	if riff.get("source") == "builtin": return
	
	# Find real index in user list? RiffManager handles deletion by list index?
	# Implementation detail: RiffManager expects index in user_riffs array. 
	# But here we merged lists. We need to find the specific user riff index.
	# Simplest way: Riff stores ID? logic in RiffManager: delete_riff(interval, riff_data)?
	
	# Let's fix RiffManager to delete by ID or Object match to be safe.
	# For now, let's just assume we pass the item to manager to find and remove.
	# Actually RiffManager.delete_riff takes index. We must calc index shift.
	
	# Calculate offset
	var builtins_count = 0
	for r in current_riffs:
		if r.source == "builtin": builtins_count += 1
		
	var user_index = selected_riff_index - builtins_count
	if user_index >= 0:
		GameManager.get_node("RiffManager").delete_riff(target_interval, user_index)
		_refresh_list()

func _save_current():
	var title = title_input.text
	var note_data = recorded_notes.duplicate()
	
	var data = {
		"title": title,
		"notes": note_data,
		"source": "user"
	}
	
	# If we are selecting a user riff, we overwrite? 
	# Implementing "Add New" vs "Edit" is tricky with just one Save button.
	# Let's assume Save always Adds New for now, or Updates if ID matches.
	# But we didn't store ID in RiffManager properly (just appended).
	# Let's simple: Save -> Add New. Delete -> Remove old.
	
	GameManager.get_node("RiffManager").add_riff(target_interval, data)
	_refresh_list()
	status_label.text = "Saved!"
