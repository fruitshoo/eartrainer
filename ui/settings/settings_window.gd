class_name SettingsWindow
extends Control

# ============================================================
# SIGNALS
# ============================================================
signal toggled(is_open: bool)

# ============================================================
# CONSTANTS & STATE
# ============================================================
const PANEL_WIDTH := 320.0
const TWEEN_DURATION := 0.3

var content_container: VBoxContainer
var is_open: bool = false
var _tween: Tween

# Labels to update dynamically
var focus_value_label: Label
var deadzone_value_label: Label
var notation_option: OptionButton
var string_focus_option: OptionButton # [New]

func _ready() -> void:
	# 1. Build the UI Hierarchy
	_build_ui()
	
	# 2. Initial Setup
	_update_position(false)
	visible = false
	_sync_settings_from_game_manager()

func _input(event: InputEvent) -> void:
	if not is_open: return
	
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ============================================================
# PUBLIC API
# ============================================================
func open() -> void:
	visible = true
	set_open(true)
	_sync_settings_from_game_manager()

func close() -> void:
	set_open(false)

func set_open(do_open: bool) -> void:
	if is_open != do_open:
		is_open = do_open
		_animate_slide(do_open)
		toggled.emit(do_open)
		EventBus.settings_visibility_changed.emit(do_open)

func _update_position(do_open: bool) -> void:
	if do_open:
		offset_left = - PANEL_WIDTH
		offset_right = 0
	else:
		offset_left = 0
		offset_right = PANEL_WIDTH

func _animate_slide(do_open: bool) -> void:
	if _tween: _tween.kill()
	var target_l = - PANEL_WIDTH if do_open else 0.0
	var target_r = 0.0 if do_open else PANEL_WIDTH
	
	if do_open: visible = true
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	_tween.tween_property(self, "offset_left", target_l, TWEEN_DURATION)
	_tween.tween_property(self, "offset_right", target_r, TWEEN_DURATION)
	
	if not do_open:
		_tween.set_parallel(false) # Follow-up after parallel
		_tween.tween_callback(func(): visible = false)

# ============================================================
# UI BUILDER
# ============================================================
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_margin.add_theme_constant_override("margin_top", 100)
	root_margin.add_theme_constant_override("margin_bottom", 120)
	add_child(root_margin)
	
	var bg = PanelContainer.new()
	root_margin.add_child(bg)
	
	# Light Theme Style (Sync with main_theme.tres)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.98, 0.98, 1, 0.75)
	bg_style.corner_radius_top_left = 24
	bg_style.corner_radius_bottom_left = 24
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(1, 1, 1, 0.5)
	bg_style.shadow_color = Color(0, 0, 0, 0.1)
	bg_style.shadow_size = 8
	bg.add_theme_stylebox_override("panel", bg_style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	bg.add_child(main_vbox)
	
	# --- Content Area ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 20)
	scroll_margin.add_theme_constant_override("margin_right", 20)
	scroll_margin.add_theme_constant_override("margin_top", 24)
	scroll_margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(scroll_margin)
	
	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 24)
	scroll_margin.add_child(content_container)
	
	# --- SECTIONS ---
	_build_volume_section()
	_build_notation_section()
	_build_display_section()
	_build_camera_section()

# ============================================================
# SECTION BUILDERS
# ============================================================

func _build_volume_section() -> void:
	_add_header("Volume")
	var grid = _add_grid()
	
	_add_volume_slider(grid, "Master", "Master")
	_add_volume_slider(grid, "Chord", "Chord")
	_add_volume_slider(grid, "Melody", "Melody")
	_add_volume_slider(grid, "SFX", "SFX")
	
	_add_divider()

func _build_notation_section() -> void:
	_add_header("Notation")
	var grid = _add_grid()
	
	var label = Label.new()
	label.text = "Label Type"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	
	notation_option = OptionButton.new()
	notation_option.size_flags_horizontal = Control.SIZE_SHRINK_END
	notation_option.custom_minimum_size = Vector2(120, 0)
	notation_option.focus_mode = Control.FOCUS_NONE
	
	notation_option.add_item("CDE", 0)
	notation_option.add_item("도레미", 1)
	notation_option.add_item("123 (Degree)", 2)
	
	notation_option.item_selected.connect(func(idx):
		GameManager.current_notation_mode = idx
		GameManager.save_settings()
	)
	
	grid.add_child(notation_option)
	
	_add_divider()

func _build_display_section() -> void:
	_add_header("Display Options")
	var grid = _add_grid()
	
	_add_checkbox(grid, "Labels", func(v): GameManager.show_note_labels = v)
	_add_checkbox(grid, "Root", func(v): GameManager.highlight_root = v)
	_add_checkbox(grid, "Chord", func(v): GameManager.highlight_chord = v)
	_add_checkbox(grid, "Scale", func(v): GameManager.highlight_scale = v)
	
	_add_divider()

func _build_camera_section() -> void:
	_add_header("Camera")
	var grid = _add_grid()
	
	# String Focus (Vertical)
	var str_lbl = Label.new()
	str_lbl.text = "String Focus"
	str_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(str_lbl)
	
	string_focus_option = OptionButton.new()
	string_focus_option.size_flags_horizontal = Control.SIZE_SHRINK_END
	string_focus_option.custom_minimum_size = Vector2(140, 0)
	string_focus_option.focus_mode = Control.FOCUS_NONE
	
	string_focus_option.add_item("All Strings (6)", 6)
	string_focus_option.add_item("Wide (+/- 2)", 2)
	string_focus_option.add_item("Standard (+/- 1)", 1)
	string_focus_option.add_item("Single String", 0)
	
	string_focus_option.item_selected.connect(func(idx):
		var range_val = string_focus_option.get_item_id(idx)
		GameManager.string_focus_range = range_val
		GameManager.save_settings()
	)
	
	grid.add_child(string_focus_option)
	
	# Focus Range (Horizontal)
	var focus_lbl = Label.new()
	focus_lbl.text = "Focus Range"
	focus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(focus_lbl)
	
	var focus_ctrls = HBoxContainer.new()
	focus_ctrls.size_flags_horizontal = Control.SIZE_SHRINK_END
	focus_ctrls.add_theme_constant_override("separation", 4)
	
	var f_minus = _create_mini_button("-", func(): _adjust_focus_range(-1))
	focus_ctrls.add_child(f_minus)
	
	focus_value_label = _create_value_label("3")
	focus_ctrls.add_child(focus_value_label)
	
	var f_plus = _create_mini_button("+", func(): _adjust_focus_range(1))
	focus_ctrls.add_child(f_plus)
	
	grid.add_child(focus_ctrls)
	
	# Deadzone
	var dead_lbl = Label.new()
	dead_lbl.text = "Deadzone"
	dead_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(dead_lbl)
	
	var dead_ctrls = HBoxContainer.new()
	dead_ctrls.size_flags_horizontal = Control.SIZE_SHRINK_END
	dead_ctrls.add_theme_constant_override("separation", 4)
	
	var d_minus = _create_mini_button("-", func(): _adjust_deadzone(-0.5))
	dead_ctrls.add_child(d_minus)
	
	deadzone_value_label = _create_value_label("4.0")
	dead_ctrls.add_child(deadzone_value_label)
	
	var d_plus = _create_mini_button("+", func(): _adjust_deadzone(0.5))
	dead_ctrls.add_child(d_plus)
	
	grid.add_child(dead_ctrls)

# ============================================================
# HELPER FUNCTIONS
# ============================================================

func _add_header(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(label)

func _add_grid() -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	content_container.add_child(grid)
	return grid

func _add_divider() -> void:
	content_container.add_child(HSeparator.new())

func _add_checkbox(parent: Node, text: String, callback: Callable) -> CheckBox:
	var cb = CheckBox.new()
	cb.text = text
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.focus_mode = Control.FOCUS_NONE
	
	# Custom Style for Checkbox (Hover/Pressed) to improve visibility on light DB
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0, 0, 0, 0.05)
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.content_margin_left = 8
	
	cb.add_theme_stylebox_override("hover", hover_style)
	cb.add_theme_stylebox_override("pressed", hover_style)
	cb.add_theme_stylebox_override("focus", hover_style)
	
	# Connect callback
	cb.toggled.connect(callback)
	
	# Store ID for syncing if needed, or just rely on state
	cb.set_meta("key", text) # Simple identifier
	
	parent.add_child(cb)
	return cb

func _add_volume_slider(parent: Node, label_text: String, bus_name: String) -> void:
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(160, 0)
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Sync initial value
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	
	slider.value_changed.connect(func(val):
		var idx = AudioServer.get_bus_index(bus_name)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(val))
			AudioServer.set_bus_mute(idx, val < 0.01)
	)
	
	parent.add_child(slider)

func _create_mini_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(32, 0)
	btn.pressed.connect(callback)
	return btn

func _create_value_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(40, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

# ============================================================
# SYNC LOGIC
# ============================================================
func _sync_settings_from_game_manager() -> void:
	# Recursive or direct finding is tricky with code-gen if we don't store refs.
	# But we can iterate grids.
	# Helper to find checkbox by meta key in a grid
	var find_cb = func(_grid_idx: int, key: String) -> CheckBox:
		# Grids are children 1, 4, 7... of content_container (Header, Grid, Divider...)
		# But easier to just traverse
		for child in content_container.get_children():
			if child is GridContainer:
				for item in child.get_children():
					if item is CheckBox and item.has_meta("key") and item.get_meta("key") == key:
						return item
		return null

	# Notation
	if notation_option:
		notation_option.select(GameManager.current_notation_mode)
	
	# Display
	var cb_lbl = find_cb.call(0, "Labels")
	if cb_lbl: cb_lbl.set_pressed_no_signal(GameManager.show_note_labels)
	
	var cb_root = find_cb.call(0, "Root")
	if cb_root: cb_root.set_pressed_no_signal(GameManager.highlight_root)
	
	var cb_chord = find_cb.call(0, "Chord")
	if cb_chord: cb_chord.set_pressed_no_signal(GameManager.highlight_chord)
	
	var cb_scale = find_cb.call(0, "Scale")
	if cb_scale: cb_scale.set_pressed_no_signal(GameManager.highlight_scale)
	
	# Camera Labels
	if focus_value_label:
		focus_value_label.text = str(GameManager.focus_range)
	if deadzone_value_label:
		deadzone_value_label.text = str(GameManager.camera_deadzone)
		
	if string_focus_option:
		var current_range = GameManager.string_focus_range
		# Find item index by ID (range value)
		for i in range(string_focus_option.item_count):
			if string_focus_option.get_item_id(i) == current_range:
				string_focus_option.select(i)
				break

func _adjust_focus_range(delta: int) -> void:
	GameManager.focus_range = clampi(GameManager.focus_range + delta, 1, 12)
	if focus_value_label:
		focus_value_label.text = str(GameManager.focus_range)
	GameManager.save_settings()

func _adjust_deadzone(delta: float) -> void:
	GameManager.camera_deadzone = clampf(GameManager.camera_deadzone + delta, 0.0, 10.0)
	if deadzone_value_label:
		deadzone_value_label.text = str(GameManager.camera_deadzone)
	GameManager.save_settings()
