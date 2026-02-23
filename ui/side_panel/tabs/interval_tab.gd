class_name ETIntervalTab
extends RefCounted

var panel: Node # SidePanel
var et_checkboxes: Dictionary = {}
var pending_manage_interval: int = -1

func _init(p_panel: Node) -> void:
	panel = p_panel

func setup() -> void:
	_populate_et_grid()
	_sync_et_state()
	
	if panel.et_asc_mode: panel._setup_mode_button(panel.et_asc_mode, "↗", QuizManager.IntervalMode.ASCENDING, ThemeColors.MODE_ASC, 0)
	if panel.et_desc_mode: panel._setup_mode_button(panel.et_desc_mode, "↘", QuizManager.IntervalMode.DESCENDING, ThemeColors.MODE_DESC, 1)
	if panel.et_harm_mode: panel._setup_mode_button(panel.et_harm_mode, "≡", QuizManager.IntervalMode.HARMONIC, ThemeColors.MODE_HARM, 2)
	
	if panel.et_easy_mode:
		panel.et_easy_mode.button_pressed = GameManager.show_target_visual
		panel.et_easy_mode.toggled.connect(func(on):
			GameManager.show_target_visual = on
			GameManager.save_settings()
		)

func _populate_et_grid() -> void:
	if not panel.et_interval_grid: return
	for child in panel.et_interval_grid.get_children(): child.queue_free()
	et_checkboxes.clear()
	
	var data = IntervalQuizData.INTERVALS
	var sorted_semitones = data.keys()
	sorted_semitones.sort()
	
	for semitones in sorted_semitones:
		var info = data[semitones]
		var is_checked = semitones in QuizManager.active_intervals
		var tile = _create_interval_tile(semitones, info, is_checked)
		panel.et_interval_grid.add_child(tile)
		et_checkboxes[semitones] = tile

	_setup_interval_options_ui()

func _setup_interval_options_ui() -> void:
	var wrong_parent = panel.et_interval_grid.get_parent()
	if wrong_parent and wrong_parent.has_node("IntervalOptions"):
		wrong_parent.get_node("IntervalOptions").queue_free()
		
	if panel.interval_container.has_node("IntervalOptionsPad"):
		panel.interval_container.get_node("IntervalOptionsPad").queue_free()
	
	var options_container = VBoxContainer.new()
	options_container.name = "IntervalOptions"
	options_container.add_theme_constant_override("separation", 8)
	
	var pad = MarginContainer.new()
	pad.name = "IntervalOptionsPad"
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.add_child(options_container)
	
	panel.interval_container.add_child(pad)
	panel.interval_container.move_child(pad, 0)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	options_container.add_child(grid)
	
	var diatonic_check = CheckBox.new()
	diatonic_check.text = "Diatonic"
	diatonic_check.tooltip_text = "Only in-key intervals"
	diatonic_check.button_pressed = QuizManager.interval_diatonic_mode
	diatonic_check.focus_mode = Control.FOCUS_NONE
	diatonic_check.toggled.connect(func(on):
		QuizManager.interval_diatonic_mode = on
		QuizManager.save_interval_settings()
	)
	grid.add_child(diatonic_check)
	
	var context_check = CheckBox.new()
	context_check.text = "Context"
	context_check.tooltip_text = "Play I-IV-V-I cadence first"
	context_check.button_pressed = QuizManager.interval_harmonic_context
	context_check.focus_mode = Control.FOCUS_NONE
	context_check.toggled.connect(func(on):
		QuizManager.interval_harmonic_context = on
		QuizManager.save_interval_settings()
	)
	grid.add_child(context_check)
	
	var anchor_check = CheckBox.new()
	anchor_check.text = "Fixed Pos"
	anchor_check.tooltip_text = "Keep same root/position"
	anchor_check.button_pressed = QuizManager.interval_fixed_anchor
	anchor_check.focus_mode = Control.FOCUS_NONE
	anchor_check.toggled.connect(func(on):
		QuizManager.interval_fixed_anchor = on
		QuizManager.save_interval_settings()
	)
	grid.add_child(anchor_check)
	
	var string_hbox = HBoxContainer.new()
	string_hbox.add_theme_constant_override("separation", 8)
	var string_label = Label.new()
	string_label.text = "Strings: "
	string_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	string_hbox.add_child(string_label)
	
	var string_opt = OptionButton.new()
	string_opt.focus_mode = Control.FOCUS_NONE
	string_opt.add_item("All", 0)
	string_opt.add_item("Same", 1)
	string_opt.add_item("Cross", 2)
	string_opt.selected = QuizManager.interval_string_constraint
	string_opt.item_selected.connect(func(idx):
		QuizManager.interval_string_constraint = idx
		QuizManager.save_interval_settings()
	)
	string_hbox.add_child(string_opt)
	options_container.add_child(string_hbox)
	
	var sep = HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.3)
	options_container.add_child(sep)

func _create_interval_tile(semitones: int, info: Dictionary, is_checked: bool) -> Button:
	var btn = Button.new()
	btn.text = info.short
	btn.custom_minimum_size = Vector2(80, 80)
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_checked
	
	panel._update_tile_style(btn, info.color, is_checked)
	
	btn.toggled.connect(func(on):
		_on_et_interval_toggled(on, semitones)
		panel._update_tile_style(btn, info.color, on)
	)
	
	btn.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			panel._show_example_manager_dialog(semitones)
	)
	
	return btn

func _on_et_interval_toggled(on: bool, semitones: int) -> void:
	if on:
		if not semitones in QuizManager.active_intervals: QuizManager.active_intervals.append(semitones)
	else: QuizManager.active_intervals.erase(semitones)

func _on_et_mode_toggled(on: bool, mode: int) -> void:
	if on:
		if not mode in QuizManager.active_modes: QuizManager.active_modes.append(mode)
	else:
		QuizManager.active_modes.erase(mode)
		if QuizManager.active_modes.is_empty():
			QuizManager.active_modes.append(mode)
			_sync_et_state()

func _sync_et_state() -> void:
	var modes = QuizManager.active_modes
	if panel.et_asc_mode:
		panel.et_asc_mode.set_pressed_no_signal(QuizManager.IntervalMode.ASCENDING in modes)
		panel._update_mode_button_style(panel.et_asc_mode, Color("#81ecec"), panel.et_asc_mode.button_pressed, 0)
		
	if panel.et_desc_mode:
		panel.et_desc_mode.set_pressed_no_signal(QuizManager.IntervalMode.DESCENDING in modes)
		panel._update_mode_button_style(panel.et_desc_mode, Color("#fab1a0"), panel.et_desc_mode.button_pressed, 1)
		
	if panel.et_harm_mode:
		panel.et_harm_mode.set_pressed_no_signal(QuizManager.IntervalMode.HARMONIC in modes)
		panel._update_mode_button_style(panel.et_harm_mode, Color("#ffeaa7"), panel.et_harm_mode.button_pressed, 2)
		
	if panel.et_easy_mode: panel.et_easy_mode.set_pressed_no_signal(GameManager.show_target_visual)
