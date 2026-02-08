class_name SettingsWindow
extends Control

# ============================================================
# STATE & REFERENCES
# ============================================================
var content_container: VBoxContainer
var close_button: Button

# Labels to update dynamically
var focus_value_label: Label
var deadzone_value_label: Label

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	# 1. Build the UI Hierarchy
	_build_ui()
	
	# 2. Initial Setup
	visible = false
	_sync_settings_from_game_manager()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ============================================================
# PUBLIC API
# ============================================================
func open() -> void:
	visible = true
	_sync_settings_from_game_manager()
	# Optional: Animate pop in

func close() -> void:
	visible = false
	EventBus.request_close_settings.emit()

# ============================================================
# UI BUILDER
# ============================================================
func _build_ui() -> void:
	# Root resizing
	anchors_preset = Control.PRESET_FULL_RECT
	
	# 1. Dimmer Background
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.4)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	
	# 2. Centering Container
	var center_cont = CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_cont)
	
	# 3. Panel Container
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	panel.theme_type_variation = "PanelContainerGlass"
	center_cont.add_child(panel)
	
	# 4. Margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	# 5. Main VBox (Title + Scroll)
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)
	
	# --- Title Row ---
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)
	
	var title_lbl = Label.new()
	title_lbl.text = "Settings"
	title_lbl.theme_type_variation = "HeaderMedium"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	
	close_button = Button.new()
	close_button.text = "✖"
	close_button.flat = true
	close_button.pressed.connect(close)
	title_row.add_child(close_button)
	
	# --- Scroll & Content ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	# Inner Margin for Content (Spacing from Scrollbar)
	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", 12) # Padding for Scrollbar
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
	
	_add_checkbox(grid, "CDE", func(v):
		GameManager.show_notation_cde = v
		GameManager.save_settings()
	)
	_add_checkbox(grid, "도레미", func(v):
		GameManager.show_notation_doremi = v
		GameManager.save_settings()
	)
	_add_checkbox(grid, "123 (Degree)", func(v):
		GameManager.show_notation_degree = v
		GameManager.save_settings()
	)
	
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
	
	# Focus Range
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
	var find_cb = func(grid_idx: int, key: String) -> CheckBox:
		# Grids are children 1, 4, 7... of content_container (Header, Grid, Divider...)
		# But easier to just traverse
		for child in content_container.get_children():
			if child is GridContainer:
				for item in child.get_children():
					if item is CheckBox and item.has_meta("key") and item.get_meta("key") == key:
						return item
		return null

	# Notation
	var cb_cde = find_cb.call(0, "CDE")
	if cb_cde: cb_cde.set_pressed_no_signal(GameManager.show_notation_cde)
	
	var cb_dorem = find_cb.call(0, "도레미")
	if cb_dorem: cb_dorem.set_pressed_no_signal(GameManager.show_notation_doremi)
	
	var cb_deg = find_cb.call(0, "123 (Degree)")
	if cb_deg: cb_deg.set_pressed_no_signal(GameManager.show_notation_degree)
	
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
