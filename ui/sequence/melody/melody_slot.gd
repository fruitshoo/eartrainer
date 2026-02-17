extends Button

signal melody_slot_clicked(bar_idx: int, beat_idx: int, sub_idx: int)
signal melody_slot_right_clicked(bar_idx: int, beat_idx: int, sub_idx: int)
signal melody_slot_hovered(bar_idx: int, beat_idx: int, sub_idx: int)
signal melody_slot_drag_released()

var bar_index: int = -1
var beat_index: int = -1
var sub_index: int = -1 # 0 or 1 (8th note)

var _is_active: bool = false
var _is_sustain: bool = false
var _note_data: Dictionary = {}

func setup(bar: int, beat: int, sub: int) -> void:
	bar_index = bar
	beat_index = beat
	sub_index = sub
	text = ""
	
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

func update_info(data: Dictionary) -> void:
	_note_data = data
	_is_active = not data.is_empty()
	_is_sustain = data.get("is_sustain", false)
	
	_update_visuals()

func _update_visuals() -> void:
	# [New] Unified StyleBox with consistent 2px corner radius
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(2)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	
	if _is_active:
		var note_label = GameManager.get_note_label(_note_data.get("root", 60))
		var display_text = note_label.replace("#", "♯").replace("b", "♭")
		
		# [New] 16th note pair display
		var has_sub = _note_data.has("sub_note")
		var is_16th = _note_data.get("duration", 0.5) <= 0.25
		
		if has_sub:
			var sub = _note_data["sub_note"]
			var sub_label = GameManager.get_note_label(sub.get("root", 60))
			sub_label = sub_label.replace("#", "♯").replace("b", "♭")
			display_text = "%s|%s" % [display_text, sub_label]
			style.bg_color = Color(0.3, 0.65, 0.5, 1.0) # Teal for 16th pair
		elif is_16th and not _is_sustain:
			# Single 16th note (front half only)
			style.bg_color = Color(0.25, 0.55, 0.4, 0.9) # Dimmer teal
		elif _is_sustain:
			display_text = "—" # Continuation marker
			style.bg_color = Color(0.2, 0.4, 0.2, 0.8) # Darker green
			style.corner_radius_top_left = 0
			style.corner_radius_bottom_left = 0
		else:
			style.bg_color = Color(0.3, 0.7, 0.3, 1.0) # Solid Green (8th note)
		
		text = display_text
		add_theme_color_override("font_color", Color.WHITE)
		add_theme_font_size_override("font_size", 10 if not has_sub else 8)
		modulate = Color(1, 1, 1, 1) # Reset modulation
	else:
		text = ""
		# Translucent dark background for empty slots to maintain unified look
		style.bg_color = Color(0.15, 0.15, 0.15, 0.3)
		
		remove_theme_color_override("font_color")
		remove_theme_font_size_override("font_size")
		modulate = Color(1, 1, 1, 0.3) # Dimmed
	
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)

func _on_mouse_entered() -> void:
	melody_slot_hovered.emit(bar_index, beat_index, sub_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				melody_slot_clicked.emit(bar_index, beat_index, sub_index)
			else:
				melody_slot_drag_released.emit()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				melody_slot_right_clicked.emit(bar_index, beat_index, sub_index)
			else:
				melody_slot_drag_released.emit()
			accept_event()

func set_highlight(is_selected: bool) -> void:
	if is_selected:
		# Use a golden tint for selection
		modulate = Color(1.5, 1.5, 1.1)
	else:
		# Reset to normal visuals
		modulate = Color(1, 1, 1, 1)
		_update_visuals()
