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

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	
	# [v1.7] Text Styling (Moved to _ready)
	if label:
		label.add_theme_font_size_override("font_size", 36) # Ultra Large (v1.9)
		label.add_theme_constant_override("outline_size", 4) # Softer Outline (v2.0)
		label.add_theme_color_override("outline_color", Color(1, 1, 1, 0.4)) # Soft light outline for depth
		label.add_theme_color_override("font_color", Color("#2C222C")) # Default: Dark Graphite

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
		tick.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Input handling
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
	var theme = GameManager.current_theme_name
	
	# Active Color (Vibrant Gold from Theme)
	var active_color = ThemeManager.get_color(theme, "root")
	# Hover Color (Semi-transparent white/light)
	var hover_color = Color(1, 1, 1, 0.3)
	
	for i in range(ticks.size()):
		var tick = ticks[i]
		
		# Start with clean slate
		tick.self_modulate = Color(1, 1, 1, 0) # Transparent by default
		
		# Priority 1: Playhead (Solid Color Fill)
		if _active_beat_index != -1 and i <= _active_beat_index:
			tick.self_modulate = active_color
			
		# Priority 2: Hover Preview (Additive Ghost Fill)
		elif _hover_beat_index != -1 and i <= _hover_beat_index:
			tick.self_modulate = hover_color

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
	
	label.text = "%s%s" % [degree, data.type]
	tooltip_text = "%s (%s%s)" % [label.text, root_name, data.type]
	
	# [v2.1] Unified Text Color: Dark Graphite
	label.add_theme_color_override("font_color", Color("#2C222C"))
	
	# [v1.7] Dynamic Background Coloring (Diatonic vs Non-Diatonic)
	_update_slot_background(data.root, data.type)

func _update_slot_background(chord_root: int, chord_type: String) -> void:
	# 1. Determine if Diatonic
	var is_diatonic = false
	if MusicTheory.is_in_scale(chord_root, GameManager.current_key, GameManager.current_mode):
		var expected = MusicTheory.get_diatonic_type(chord_root, GameManager.current_key, GameManager.current_mode)
		if chord_type == expected:
			is_diatonic = true
			
	# 2. Reset if Diatonic (v1.9: No background for Diatonic)
	if is_diatonic:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		return
		
	# 3. Apply Style for Non-Diatonic
	var bg_color = Color(0.35, 0.35, 0.4) # Cool Grey (Clean & Modern)
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.bg_color = bg_color
	# Add border for pop
	style.border_width_bottom = 4
	style.border_color = bg_color.darkened(0.2)
	
	add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = bg_color.lightened(0.1)
	add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = bg_color.darkened(0.1)
	pressed_style.border_width_bottom = 2 # Press effect
	add_theme_stylebox_override("pressed", pressed_style)

func set_highlight(state: String) -> void:
	# state: "playing", "selected", "none"
	match state:
		"playing":
			modulate = Color(0.8, 1.3, 1.3) # 시안/민트 (Glassmorphism)
		"selected":
			modulate = Color(1.5, 1.5, 1.0) # 노란색 (편집 대기)
		"loop":
			modulate = Color(1.0, 1.0, 1.0) # 흰색 (루프 구간 - 오버레이로 표시하므로 버튼은 평범하게)
		_:
			modulate = Color.WHITE

func _update_default_visual() -> void:
	if label:
		label.text = "Slot %d" % (slot_index + 1)
		
	# Reset background
	remove_theme_stylebox_override("normal")
	remove_theme_stylebox_override("hover")
	remove_theme_stylebox_override("pressed")

signal right_clicked(index: int)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(slot_index)
		accept_event()
