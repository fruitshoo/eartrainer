class_name ETProgressionTab
extends RefCounted

var panel: Node # SidePanel
var _prog_degree_btns: Array[Button] = []

func _init(p_panel: Node) -> void:
	panel = p_panel

func setup() -> void:
	_setup_progression_tab_ui()

func _setup_progression_tab_ui() -> void:
	# 1. Add Tab Button
	panel.tab_prog_btn.text = "PRG"
	panel.tab_prog_btn.toggle_mode = true
	panel.tab_prog_btn.focus_mode = Control.FOCUS_NONE
	panel.tab_prog_btn.custom_minimum_size.y = 40
	panel.tabs_hbox.add_child(panel.tab_prog_btn)
	panel.tabs_hbox.move_child(panel.tab_prog_btn, 2) # Insert after Chord
	
	# 2. Create Container
	panel.progression_container = VBoxContainer.new()
	panel.progression_container.name = "ProgressionContainer"
	panel.progression_container.visible = false
	panel.progression_container.add_theme_constant_override("separation", 16)
	panel.main_vbox.add_child(panel.progression_container)
	panel.main_vbox.move_child(panel.progression_container, panel.chord_container.get_index() + 1)
	
	# 3. Slots Visualizer
	var slots_frame = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	slots_frame.add_theme_stylebox_override("panel", style)
	
	var slots_scroll = ScrollContainer.new()
	slots_scroll.name = "SlotsScroll"
	slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	slots_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_frame.add_child(slots_scroll)
	
	panel.progression_slots_container = HBoxContainer.new()
	panel.progression_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.progression_slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Ensure it fills scroll area
	panel.progression_slots_container.add_theme_constant_override("separation", 10)
	slots_scroll.add_child(panel.progression_slots_container)
	
	panel.progression_container.add_child(slots_frame)
	
	# [New] Difficulty System Slider
	var diff_box = VBoxContainer.new()
	var diff_header = HBoxContainer.new()
	
	var diff_lbl = Label.new()
	diff_lbl.text = "Difficulty Level: "
	diff_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	diff_header.add_child(diff_lbl)
	
	var diff_val_lbl = Label.new()
	diff_val_lbl.text = str(QuizManager.progression_level)
	diff_val_lbl.add_theme_color_override("font_color", ThemeColors.TOGGLE_ON)
	diff_header.add_child(diff_val_lbl)
	
	diff_box.add_child(diff_header)
	
	var diff_slider = HSlider.new()
	diff_slider.min_value = 1
	diff_slider.max_value = 7
	diff_slider.step = 1
	diff_slider.value = QuizManager.progression_level
	diff_slider.value_changed.connect(func(val):
		QuizManager.progression_level = int(val)
		diff_val_lbl.text = str(val) + " (" + str(val + 1) + " Chords)"
		QuizManager.save_chord_settings()
	)
	
	# Initial label config
	diff_val_lbl.text = str(QuizManager.progression_level) + " (" + str(QuizManager.progression_level + 1) + " Chords)"
	
	diff_box.add_child(diff_slider)
	
	# [New] Power Chords Toggle
	var dist_box = HBoxContainer.new()
	var pwr_lbl = Label.new()
	pwr_lbl.text = "Power Chords Only"
	pwr_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	pwr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist_box.add_child(pwr_lbl)
	
	var pwr_toggle = CheckButton.new()
	pwr_toggle.button_pressed = QuizManager.use_power_chords
	pwr_toggle.toggled.connect(func(pressed):
		QuizManager.use_power_chords = pressed
		QuizManager.save_chord_settings()
	)
	dist_box.add_child(pwr_toggle)
	diff_box.add_child(dist_box)
	
	panel.progression_container.add_child(diff_box)
	
	# 4. Input Buttons (I through vii) - NOW FILTERS
	var input_grid = GridContainer.new()
	input_grid.columns = 4
	input_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	input_grid.add_theme_constant_override("h_separation", 8)
	input_grid.add_theme_constant_override("v_separation", 8)
	
	var degrees = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
	_prog_degree_btns.clear()
	
	for i in range(degrees.size()):
		var btn = Button.new()
		btn.text = degrees[i]
		btn.custom_minimum_size = Vector2(64, 45)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true # [New] Toggle behavior for filters
		
		# Initialize toggle state from manager
		btn.button_pressed = i in QuizManager.active_progression_degrees
		
		btn.pressed.connect(func():
			_on_degree_filter_toggled(i, btn.button_pressed)
		)
		input_grid.add_child(btn)
		_prog_degree_btns.append(btn)
		
	panel.progression_container.add_child(input_grid)
	_update_degree_filter_visuals()

func _on_degree_filter_toggled(degree_idx: int, is_pressed: bool) -> void:
	var active = QuizManager.active_progression_degrees
	if is_pressed:
		if not degree_idx in active:
			active.append(degree_idx)
	else:
		active.erase(degree_idx)
	
	if active.is_empty():
		active.append(degree_idx)
		_prog_degree_btns[degree_idx].button_pressed = true
		
	_update_degree_filter_visuals()
	QuizManager.save_chord_settings() # [New] Save filter preferences

func _update_degree_filter_visuals() -> void:
	for i in range(_prog_degree_btns.size()):
		var btn = _prog_degree_btns[i]
		var is_active = i in QuizManager.active_progression_degrees
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		if is_active:
			style.bg_color = ThemeColors.FILTER_ACTIVE_BG
			style.set_border_width_all(2)
			style.border_color = ThemeColors.FILTER_ACTIVE_BORDER
		else:
			style.bg_color = ThemeColors.SLOT_FUTURE_BG
			style.set_border_width_all(1)
			style.border_color = ThemeColors.SLOT_FUTURE_BORDER.lightened(0.1)
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func update_progression_slots_active(step_idx: int) -> void:
	if not panel.progression_slots_container: return
	var slots = panel.progression_slots_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot is PanelContainer: continue
		
		var style = slot.get_theme_stylebox("panel").duplicate()
		if i == step_idx:
			style.border_color = ThemeColors.SLOT_ACTIVE_BORDER
			style.bg_color = ThemeColors.SLOT_ACTIVE_BG
			slot.modulate.a = 1.0
		elif i < step_idx:
			style.border_color = ThemeColors.SLOT_DONE_BORDER
			style.bg_color = ThemeColors.SLOT_DONE_BG
			slot.modulate.a = 1.0
		else:
			style.border_color = ThemeColors.SLOT_FUTURE_BORDER
			style.bg_color = ThemeColors.SLOT_FUTURE_BG
			slot.modulate.a = 0.5
		slot.add_theme_stylebox_override("panel", style)

func animate_slot_pop(slot: Control) -> void:
	var tw = panel.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	slot.pivot_offset = slot.size / 2
	slot.scale = Vector2(0.8, 0.8)
	tw.tween_property(slot, "scale", Vector2(1, 1), 0.4)

func animate_slot_shake(slot: Control) -> void:
	var tw = panel.create_tween()
	var start_pos = slot.position
	tw.tween_property(slot, "position:x", start_pos.x + 10, 0.05)
	tw.tween_property(slot, "position:x", start_pos.x - 10, 0.05)
	tw.tween_property(slot, "position:x", start_pos.x + 10, 0.05)
	tw.tween_property(slot, "position:x", start_pos.x, 0.05)

func animate_slot_pulse(slot: Control) -> void:
	if not slot is PanelContainer: return
	
	var style = slot.get_theme_stylebox("panel").duplicate()
	var original_bg = style.bg_color
	var original_border = style.border_color
	
	# Flash visually
	style.bg_color = ThemeColors.TOGGLE_ON.lightened(0.2)
	style.border_color = Color.WHITE
	slot.add_theme_stylebox_override("panel", style)
	
	var tw = panel.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(style, "bg_color", original_bg, 0.6)
	
	var tw2 = panel.create_tween()
	tw2.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw2.tween_property(style, "border_color", original_border, 0.6)
	
	# Scale punch
	slot.pivot_offset = slot.size / 2
	slot.scale = Vector2(1.15, 1.15)
	var tw_scale = panel.create_tween()
	tw_scale.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_scale.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.6)
