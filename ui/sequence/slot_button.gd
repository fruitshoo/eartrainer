# slot_button.gd
class_name SlotButton
extends Button

# ============================================================
# STATE
# ============================================================
var slot_index: int = -1

# ============================================================
# NODES
# ============================================================
@onready var label: Label = $Label

func _init() -> void:
	focus_mode = Control.FOCUS_NONE

# ============================================================
# PUBLIC API
# ============================================================
signal beat_clicked(slot_index: int, beat_index: int)

@onready var beat_container: HBoxContainer = $BeatContainer
var beat_tick_scene: PackedScene = preload("res://ui/sequence/beat_tick.tscn")
var _total_beats: int = 4

var _active_beat_index: int = -1
var _hover_beat_index: int = -1

## [Updated] beats 인자 추가
func setup(index: int, beats: int = 4) -> void:
	slot_index = index
	_total_beats = beats
	text = ""
	
	# 비트 틱 생성
	for child in beat_container.get_children():
		child.queue_free()
	
	for i in range(beats):
		var tick = beat_tick_scene.instantiate()
		# tick.custom_minimum_size = Vector2(24, 12) # Handled by scene now
		
		# Input handling (ColorRect with mouse_filter=Stop)
		tick.gui_input.connect(_on_tick_gui_input.bind(i))
		tick.mouse_entered.connect(_on_tick_mouse_entered.bind(i))
		tick.mouse_exited.connect(_on_tick_mouse_exited.bind(i))
		
		beat_container.add_child(tick)
		
	_update_default_visual()
	_update_ticks_visual()

func update_playhead(active_beat: int) -> void:
	_active_beat_index = active_beat
	_update_ticks_visual()

func _update_ticks_visual() -> void:
	var ticks = beat_container.get_children()
	for i in range(ticks.size()):
		var tick = ticks[i]
		
		# Priority 1: Playhead (Current playback position) -> RED
		if i == _active_beat_index:
			tick.color = Color(1.0, 0.2, 0.2) # Active Red
			
		# Priority 2: Hover Preview (Progress bar style) -> White/Bright
		elif _hover_beat_index != -1 and i <= _hover_beat_index:
			tick.color = Color(0.6, 0.6, 0.6) # Hover Highlight
			
		# Priority 3: Default Inactive
		else:
			tick.color = Color(0.2, 0.2, 0.2) # Dark Grey

func _on_tick_gui_input(event: InputEvent, beat_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		beat_clicked.emit(slot_index, beat_idx)
		accept_event()

func _on_tick_mouse_entered(beat_idx: int) -> void:
	_hover_beat_index = beat_idx
	_update_ticks_visual()

func _on_tick_mouse_exited(_beat_idx: int) -> void:
	_hover_beat_index = -1
	_update_ticks_visual()

func update_info(data: Dictionary) -> void:
	if not label: return
	
	if data == null or data.is_empty():
		_update_default_visual()
		return

	var use_flats := MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var root_name := MusicTheory.get_note_name(data.root, use_flats)
	var degree := MusicTheory.get_degree_label(data.root, GameManager.current_key, GameManager.current_mode)
	
	label.text = "%s (%s%s)" % [degree, root_name, data.type]

func set_highlight(state: String) -> void:
	# state: "playing", "selected", "none"
	match state:
		"playing":
			modulate = Color(0.5, 2.0, 0.5) # 녹색
		"selected":
			modulate = Color(1.5, 1.5, 1.0) # 노란색
		_:
			modulate = Color.WHITE

func _update_default_visual() -> void:
	if label:
		label.text = "Slot %d" % (slot_index + 1)

signal right_clicked(index: int)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(slot_index)
		accept_event()
