class_name ETChordTab
extends RefCounted

var panel: Node # SidePanel

func _init(p_panel: Node) -> void:
	panel = p_panel

func setup() -> void:
	_populate_chord_grid()
	_sync_chord_state()
	
	if panel.chord_up_btn: _setup_chord_dir_button(panel.chord_up_btn, "↑", 0, ThemeColors.MODE_ASC, 0)
	if panel.chord_down_btn: _setup_chord_dir_button(panel.chord_down_btn, "↓", 1, ThemeColors.MODE_DESC, 1)
	if panel.chord_harm_btn: _setup_chord_dir_button(panel.chord_harm_btn, "≡", 2, ThemeColors.MODE_HARM, 2)
	
	if panel.chord_inv_root_btn: _setup_chord_inv_button(panel.chord_inv_root_btn, "Root", 0, ThemeColors.CHORD_ROOT, 0)
	if panel.chord_inv_1st_btn: _setup_chord_inv_button(panel.chord_inv_1st_btn, "1st", 1, ThemeColors.CHORD_1ST, 1)
	if panel.chord_inv_2nd_btn: _setup_chord_inv_button(panel.chord_inv_2nd_btn, "2nd", 2, ThemeColors.CHORD_2ND, 2)
	
	_setup_voicing_toggle()

func _populate_chord_grid() -> void:
	if not panel.chord_type_grid: return
	for child in panel.chord_type_grid.get_children(): child.queue_free()
	
	# Build 7 diatonic degree tiles
	for degree_idx in range(7):
		var chord_data = MusicTheory.get_chord_from_degree(GameManager.current_mode, degree_idx)
		if chord_data.is_empty(): continue
		
		var roman = chord_data[2] # e.g. "I", "ii", "iii", etc.
		var is_active = degree_idx in QuizManager.active_degrees
		var tile = _create_degree_tile(degree_idx, roman, is_active)
		panel.chord_type_grid.add_child(tile)

func _create_degree_tile(degree_idx: int, label: String, is_checked: bool) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(64, 45)
	btn.add_theme_font_size_override("font_size", 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_checked
	
	panel._update_tile_style(btn, ThemeColors.TOGGLE_ON, is_checked)
	
	btn.toggled.connect(func(on):
		if on:
			if not degree_idx in QuizManager.active_degrees: QuizManager.active_degrees.append(degree_idx)
		else:
			QuizManager.active_degrees.erase(degree_idx)
			# Prevent empty selection
			if QuizManager.active_degrees.is_empty():
				QuizManager.active_degrees.append(degree_idx)
				btn.set_pressed_no_signal(true)
		panel._update_tile_style(btn, ThemeColors.TOGGLE_ON, btn.button_pressed)
		QuizManager.save_chord_settings()
	)
	return btn

func _sync_chord_state() -> void:
	var dir_list = QuizManager.active_directions
	if panel.chord_up_btn: _update_chord_dir_style(panel.chord_up_btn, ThemeColors.MODE_ASC, 0 in dir_list, 0)
	if panel.chord_down_btn: _update_chord_dir_style(panel.chord_down_btn, ThemeColors.MODE_DESC, 1 in dir_list, 1)
	if panel.chord_harm_btn: _update_chord_dir_style(panel.chord_harm_btn, ThemeColors.MODE_HARM, 2 in dir_list, 2)
	
	var inv_list = QuizManager.active_inversions
	if panel.chord_inv_root_btn: _update_chord_inv_style(panel.chord_inv_root_btn, ThemeColors.CHORD_ROOT, 0 in inv_list, 0)
	if panel.chord_inv_1st_btn: _update_chord_inv_style(panel.chord_inv_1st_btn, ThemeColors.CHORD_1ST, 1 in inv_list, 1)
	if panel.chord_inv_2nd_btn: _update_chord_inv_style(panel.chord_inv_2nd_btn, ThemeColors.CHORD_2ND, 2 in inv_list, 2)
	_update_voicing_toggle_style()

func _setup_chord_dir_button(btn: Button, text: String, mode_id: int, color: Color, pos: int) -> void:
	btn.text = text
	btn.toggle_mode = true # [Fix #5] Enable multi-select toggle
	btn.pressed.connect(func():
		var list = QuizManager.active_directions
		if mode_id in list:
			list.erase(mode_id)
		else:
			list.append(mode_id)
		
		# Prevent empty selection
		if list.is_empty():
			list.append(mode_id)
		
		_sync_chord_state()
		QuizManager.save_chord_settings()
	)
	_update_chord_dir_style(btn, color, mode_id in QuizManager.active_directions, pos)

func _setup_chord_inv_button(btn: Button, text: String, mode_id: int, color: Color, pos: int) -> void:
	btn.text = text
	btn.toggle_mode = true # Ensure it behaves as a toggle
	btn.pressed.connect(func():
		var list = QuizManager.active_inversions
		if mode_id in list:
			list.erase(mode_id)
		else:
			list.append(mode_id)
		
		# Prevent empty selection (force toggle back on if it was the last one)
		if list.is_empty():
			list.append(mode_id)
			
		_sync_chord_state()
		QuizManager.save_chord_settings()
	)
	_update_chord_inv_style(btn, color, mode_id in QuizManager.active_inversions, pos)

func _update_chord_dir_style(btn: Button, color: Color, is_active: bool, pos: int) -> void:
	panel._update_mode_button_style(btn, color, is_active, pos)

func _update_chord_inv_style(btn: Button, color: Color, is_active: bool, pos: int) -> void:
	panel._update_mode_button_style(btn, color, is_active, pos)

func _setup_voicing_toggle() -> void:
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 2)
	
	panel.chord_voicing_toggle_theory = Button.new()
	panel.chord_voicing_toggle_theory.text = "이론"
	panel.chord_voicing_toggle_theory.custom_minimum_size = Vector2(60, 36)
	panel.chord_voicing_toggle_theory.add_theme_font_size_override("font_size", 13)
	panel.chord_voicing_toggle_theory.focus_mode = Control.FOCUS_NONE
	
	panel.chord_voicing_toggle_form = Button.new()
	panel.chord_voicing_toggle_form.text = "기타폼"
	panel.chord_voicing_toggle_form.custom_minimum_size = Vector2(70, 36)
	panel.chord_voicing_toggle_form.add_theme_font_size_override("font_size", 13)
	panel.chord_voicing_toggle_form.focus_mode = Control.FOCUS_NONE
	
	hbox.add_child(panel.chord_voicing_toggle_theory)
	hbox.add_child(panel.chord_voicing_toggle_form)
	
	if panel.chord_type_grid and panel.chord_type_grid.get_parent():
		var parent = panel.chord_type_grid.get_parent()
		var idx = panel.chord_type_grid.get_index() + 1
		parent.add_child(hbox)
		parent.move_child(hbox, idx)
	
	panel.chord_voicing_toggle_theory.pressed.connect(func():
		QuizManager.chord_quiz_use_voicing = false
		_update_voicing_toggle_style()
		QuizManager.save_chord_settings()
	)
	panel.chord_voicing_toggle_form.pressed.connect(func():
		QuizManager.chord_quiz_use_voicing = true
		_update_voicing_toggle_style()
		QuizManager.save_chord_settings()
	)
	
	_update_voicing_toggle_style()

func _update_voicing_toggle_style() -> void:
	var is_voicing = QuizManager.chord_quiz_use_voicing
	panel._update_tile_style(panel.chord_voicing_toggle_theory, ThemeColors.CHORD_ROOT, not is_voicing)
	panel._update_tile_style(panel.chord_voicing_toggle_form, ThemeColors.MODE_HARM.darkened(0.1), is_voicing)
