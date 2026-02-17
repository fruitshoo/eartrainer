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
	pressed.connect(func(): slot_pressed.emit(slot_index))
	
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
signal slot_pressed(index: int)

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
	var theme_name = GameManager.current_theme_name
	
	# Active Color (Vibrant Gold from Theme)
	var active_color = ThemeManager.get_color(theme_name, "root")
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

var _is_selected: bool = false
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 4.0

func _on_tick_gui_input(event: InputEvent, beat_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = false
				_drag_start_pos = event.position
			else:
				# Mouse Up (Tap)
				if not _is_dragging:
					if _is_selected:
						beat_clicked.emit(slot_index, beat_idx)
					else:
						# If not selected, clicking a beat selects the slot
						slot_pressed.emit(slot_index)
				_is_dragging = false
			accept_event()
			
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_clicked.emit(slot_index)
			accept_event()
			
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _is_dragging:
				if event.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
					_is_dragging = true
			
			if _is_dragging:
				# Scrubbing logic: Emit beat_clicked immediately
				beat_clicked.emit(slot_index, beat_idx)
				# Also ensure we highlight this beat during drag
				_on_tick_mouse_entered(beat_idx)
				accept_event()

func _on_tick_mouse_entered(beat_idx: int) -> void:
	_hover_beat_index = beat_idx
	_update_ticks_visual()
	
	# Support dragging across multiple ticks
	if _is_dragging:
		beat_clicked.emit(slot_index, beat_idx)

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
		
		# [Fix] String normalization for comparison
		# MusicTheory now returns "maj7", "min7", "dom7", "m7b5"
		
		if chord_type == expected:
			is_diatonic = true
		elif chord_type == "5":
			# Power chords are diatonic if the scale degree has a Perfect 5th
			# (i.e. expected type is NOT m7b5 or dim7)
			if expected != "m7b5" and expected != "dim7":
				is_diatonic = true
		
		# [New] For Triads (maj/min) vs 7ths compatibility
		# If quiz generates "maj7" but slot says "maj", we might want to treat as diatonic?
		# Or if slot says "maj7", expected is "maj7".
		# Let's trust exact match for now, as quiz generates full 7ths.
			
	# 2. Reset if Diatonic (v1.9: No background for Diatonic)
	if is_diatonic:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		return
		
	# 3. Apply Style for Non-Diatonic
	var bg_color = Color("#FFE5D9") # Coral (Warm, Intentional Variation)
	
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

# Updated state management
var _is_playing: bool = false
var _is_in_loop: bool = false

func set_state(playing: bool, selected: bool, in_loop: bool) -> void:
	_is_playing = playing
	_is_selected = selected
	_is_in_loop = in_loop
	
	_update_visual_state()

func _update_visual_state() -> void:
	# Priority 1: Playing (Always Blue/Cyan BG)
	if _is_playing:
		modulate = Color(0.8, 1.3, 1.3) # Cyan/Mint
		
		# If also Selected, maybe add a yellow border?
		# Currently we just use modulate, so we can't easily add a border without StyleBox.
		# For now, let's just keep Cyan. If selected, the "Gold Tick" from selection is visible?
		# No, ticks are handled separately.
		# Let's trust the "Cyan" background is distinctive enough.
		
	# Priority 2: Selected (Yellow/Gold)
	elif _is_selected:
		modulate = Color(1.5, 1.5, 1.0) # Gold/Yellow
		
	# Priority 3: Loop (White/Neutral)
	elif _is_in_loop:
		modulate = Color(1.0, 1.0, 1.0) # White
		
	# Priority 4: Normal
	else:
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
