# side_panel.gd
# 사이드 패널 UI 컨트롤러 - 이어 트레이닝 전용
class_name SidePanel
extends Control

# ============================================================
# SIGNALS
# ============================================================
signal toggled(is_open: bool)

# ============================================================
# CONSTANTS & RESOURCES
# ============================================================
const PANEL_WIDTH := 320.0
const TWEEN_DURATION := 0.3

var riff_editor_scene: PackedScene = preload("res://ui/side_panel/RiffEditor.tscn")
const ET_ROW_SCENE = preload("res://ui/side_panel/EarTrainerItemRow.tscn")
var _main_theme: Theme = preload("res://ui/resources/main_theme.tres")

# ============================================================
# UI REFERENCES
# ============================================================
var content_container: Control
var ear_trainer_content: ScrollContainer

# Ear Trainer References
var et_feedback_label: Label
var et_asc_mode: Button
var et_desc_mode: Button
var et_harm_mode: Button
var et_easy_mode: CheckBox
var et_interval_grid: GridContainer
var et_replay_btn: Button
var et_next_btn: Button

# ============================================================
# STATE
# ============================================================
var is_open: bool = false
var _tween: Tween

# Ear Trainer State
var et_checkboxes: Dictionary = {}
var pending_manage_interval: int = -1
var pending_delete_song: String = ""

# Overlays (Managed through code)
var example_manager_root: Control
var example_list_box: VBoxContainer
var import_overlay: Control
var import_option_button: OptionButton
var import_btn_ref: Button
var delete_overlay: Control
var delete_label_ref: Label

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	# 1. Build the UI
	_build_ui()
	
	# 2. Initial State
	visible = false
	_update_position(false)
	
	# 3. EventBus
	EventBus.request_collapse_side_panel.connect(close)
	
	# 4. Inits
	_populate_et_grid()
	_sync_et_state()

# ============================================================
# UI BUILDER
# ============================================================
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _main_theme
	
	var root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_margin.add_theme_constant_override("margin_top", 100) # 80 -> 100
	root_margin.add_theme_constant_override("margin_bottom", 120)
	add_child(root_margin)
	
	var bg = PanelContainer.new()
	root_margin.add_child(bg)
	
	# Rounded corners for floating look
	# Rounded corners for floating look - MATCHING main_theme.tres light style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.98, 0.98, 1, 0.75) # Light, semi-transparent
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
	content_container = Control.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.clip_contents = true
	main_vbox.add_child(content_container)
	
	_build_ear_trainer_v2_ui()

func _build_ear_trainer_v2_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	content_container.add_child(main_vbox)
	
	# 1. The Stage (Feedback Panel)
	var stage_margin = MarginContainer.new()
	stage_margin.add_theme_constant_override("margin_top", 16)
	stage_margin.add_theme_constant_override("margin_left", 16)
	stage_margin.add_theme_constant_override("margin_right", 16)
	stage_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(stage_margin)
	
	var stage_panel = PanelContainer.new()
	stage_panel.custom_minimum_size = Vector2(0, 120) # 160 -> 120
	stage_margin.add_child(stage_panel)
	
	# Glassmorphism style for Stage (White glass)
	var stage_style = StyleBoxFlat.new()
	stage_style.bg_color = Color(1, 1, 1, 0.4)
	stage_style.corner_radius_top_left = 20
	stage_style.corner_radius_top_right = 20
	stage_style.corner_radius_bottom_left = 20
	stage_style.corner_radius_bottom_right = 20
	stage_style.border_width_left = 1
	stage_style.border_width_top = 1
	stage_style.border_color = Color(1, 1, 1, 0.6)
	stage_panel.add_theme_stylebox_override("panel", stage_style)
	
	var stage_vbox = VBoxContainer.new()
	stage_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_panel.add_child(stage_vbox)
	
	et_feedback_label = Label.new()
	et_feedback_label.text = "READY"
	et_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	et_feedback_label.theme_type_variation = "HeaderLarge"
	et_feedback_label.modulate = Color("#333333") # Dark text for light theme
	et_feedback_label.pivot_offset = Vector2(100, 20)
	stage_vbox.add_child(et_feedback_label)
	
	var stage_spacer = Control.new()
	stage_spacer.custom_minimum_size = Vector2(0, 12)
	stage_vbox.add_child(stage_spacer)
	
	var stage_btns_hbox = HBoxContainer.new()
	stage_btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_btns_hbox.add_theme_constant_override("separation", 24)
	stage_vbox.add_child(stage_btns_hbox)
	
	et_replay_btn = Button.new()
	et_replay_btn.text = "REPLAY"
	et_replay_btn.custom_minimum_size = Vector2(100, 45)
	et_replay_btn.focus_mode = Control.FOCUS_NONE
	et_replay_btn.pressed.connect(QuizManager.play_current_interval)
	stage_btns_hbox.add_child(et_replay_btn)
	_setup_stage_button(et_replay_btn, Color("#34495e"))
	
	et_next_btn = Button.new()
	et_next_btn.text = "NEXT"
	et_next_btn.custom_minimum_size = Vector2(100, 45)
	et_next_btn.focus_mode = Control.FOCUS_NONE
	et_next_btn.pressed.connect(QuizManager.start_interval_quiz)
	stage_btns_hbox.add_child(et_next_btn)
	_setup_stage_button(et_next_btn, Color("#3498db"))
	
	# 2. Segmented Mode Control (Asc/Desc/Harm)
	var modes_margin = MarginContainer.new()
	modes_margin.add_theme_constant_override("margin_left", 20)
	modes_margin.add_theme_constant_override("margin_right", 20)
	modes_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(modes_margin)
	
	var modes_hbox = HBoxContainer.new()
	modes_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modes_hbox.add_theme_constant_override("separation", 0) # No separation for segmented look
	modes_margin.add_child(modes_hbox)
	
	et_asc_mode = _create_mode_button("↗", QuizManager.IntervalMode.ASCENDING, Color("#81ecec"), 0)
	et_desc_mode = _create_mode_button("↘", QuizManager.IntervalMode.DESCENDING, Color("#fab1a0"), 1)
	et_harm_mode = _create_mode_button("≡", QuizManager.IntervalMode.HARMONIC, Color("#ffeaa7"), 2)
	
	modes_hbox.add_child(et_asc_mode)
	modes_hbox.add_child(et_desc_mode)
	modes_hbox.add_child(et_harm_mode)
	
	var sep = HSeparator.new()
	sep.modulate.a = 0.2
	main_vbox.add_child(sep)
	
	# 3. Interval Tiles Grid
	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(grid_scroll)
	
	var grid_margin = MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.add_theme_constant_override("margin_left", 20)
	grid_margin.add_theme_constant_override("margin_right", 20)
	grid_margin.add_theme_constant_override("margin_top", 20)
	grid_margin.add_theme_constant_override("margin_bottom", 20)
	grid_scroll.add_child(grid_margin)
	
	et_interval_grid = GridContainer.new()
	et_interval_grid.columns = 3
	et_interval_grid.add_theme_constant_override("h_separation", 12)
	et_interval_grid.add_theme_constant_override("v_separation", 12)
	grid_margin.add_child(et_interval_grid)
	
	# Extra Setting: Easy Mode
	var easy_margin = MarginContainer.new()
	easy_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(easy_margin)
	var easy_hbox = HBoxContainer.new()
	easy_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	easy_margin.add_child(easy_hbox)
	et_easy_mode = _create_checkbox("Show Visual Hints", func(v): GameManager.show_target_visual = v, true)
	easy_hbox.add_child(et_easy_mode)
	
	QuizManager.quiz_started.connect(_on_et_quiz_started)
	QuizManager.quiz_answered.connect(_on_et_quiz_answered)

func _create_checkbox(text: String, callback: Callable, pressed: bool = false) -> CheckBox:
	var cb = CheckBox.new()
	cb.text = text
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = pressed
	cb.toggled.connect(callback)
	
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
	
	return cb

# ============================================================
# SLIDE LOGIC
# ============================================================
func toggle() -> void:
	set_open(not is_open)

func open() -> void:
	visible = true
	set_open(true)

func close() -> void:
	set_open(false)

func set_open(do_open: bool) -> void:
	if is_open != do_open:
		is_open = do_open
		_animate_slide(do_open)
		
		if not do_open:
			QuizManager.stop_quiz()
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner and is_ancestor_of(focus_owner):
				focus_owner.release_focus()
		
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
		_tween.set_parallel(false)
		_tween.tween_callback(func(): visible = false)

func _input(event: InputEvent) -> void:
	if not is_open: return
	
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var mouse_pos = get_local_mouse_position()
			if mouse_pos.x >= 0 and mouse_pos.x <= PANEL_WIDTH:
				get_viewport().set_input_as_handled()

# ============================================================
# EAR TRAINER LOGIC
# ============================================================
func _populate_et_grid() -> void:
	if not et_interval_grid: return
	for child in et_interval_grid.get_children(): child.queue_free()
	et_checkboxes.clear()
	
	var data = IntervalQuizData.INTERVALS
	var sorted_semitones = data.keys()
	sorted_semitones.sort()
	
	for semitones in sorted_semitones:
		var info = data[semitones]
		var is_checked = semitones in QuizManager.active_intervals
		var tile = _create_interval_tile(semitones, info, is_checked)
		et_interval_grid.add_child(tile)
		et_checkboxes[semitones] = tile

func _create_interval_tile(semitones: int, info: Dictionary, is_checked: bool) -> Button:
	var btn = Button.new()
	btn.text = info.short
	btn.custom_minimum_size = Vector2(80, 80)
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_checked
	
	# Initial Style
	_update_tile_style(btn, info.color, is_checked)
	
	btn.toggled.connect(func(on):
		_on_et_interval_toggled(on, semitones)
		_update_tile_style(btn, info.color, on)
	)
	
	# Long press or right click for manage? Let's use right click for now
	btn.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_example_manager_dialog(semitones)
	)
	
	return btn

func _update_tile_style(btn: Button, color: Color, is_active: bool) -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	if is_active:
		style.bg_color = color
		style.border_color = color.darkened(0.2)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		style.bg_color = Color(color.r, color.g, color.b, 0.1)
		style.border_color = Color(color.r, color.g, color.b, 0.2)
		btn.add_theme_color_override("font_color", color.darkened(0.4))
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

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
	if et_asc_mode:
		et_asc_mode.set_pressed_no_signal(QuizManager.IntervalMode.ASCENDING in modes)
		_update_mode_button_style(et_asc_mode, Color("#81ecec"), et_asc_mode.button_pressed, 0)
		
	if et_desc_mode:
		et_desc_mode.set_pressed_no_signal(QuizManager.IntervalMode.DESCENDING in modes)
		_update_mode_button_style(et_desc_mode, Color("#fab1a0"), et_desc_mode.button_pressed, 1)
		
	if et_harm_mode:
		et_harm_mode.set_pressed_no_signal(QuizManager.IntervalMode.HARMONIC in modes)
		_update_mode_button_style(et_harm_mode, Color("#ffeaa7"), et_harm_mode.button_pressed, 2)
		
	# if et_easy_mode: et_easy_mode.set_pressed_no_signal(GameManager.show_target_visual)

func _create_mode_button(text: String, mode_id: int, color: Color, pos_idx: int) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(80, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	btn.toggled.connect(func(on):
		_on_et_mode_toggled(on, mode_id)
		_update_mode_button_style(btn, color, on, pos_idx)
	)
	
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	
	_update_mode_button_style(btn, color, btn.button_pressed, pos_idx)
	return btn

func _update_mode_button_style(btn: Button, color: Color, is_active: bool, pos_idx: int) -> void:
	var style = StyleBoxFlat.new()
	
	# Segmented Corners
	style.corner_radius_top_left = 12 if pos_idx == 0 else 0
	style.corner_radius_bottom_left = 12 if pos_idx == 0 else 0
	style.corner_radius_top_right = 12 if pos_idx == 2 else 0
	style.corner_radius_bottom_right = 12 if pos_idx == 2 else 0
	
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1 if pos_idx == 2 else 0
	style.border_width_bottom = 1
	
	if is_active:
		style.bg_color = color.lightened(0.1)
		style.border_color = color.darkened(0.1)
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	else:
		style.bg_color = Color(0, 0, 0, 0.03) # Subtle indent
		style.border_color = Color(0, 0, 0, 0.1)
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0.5))
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func _setup_stage_button(btn: Button, color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20
	normal.bg_color = Color(color.r, color.g, color.b, 0.6)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(1, 1, 1, 0.3)
	
	var hover = normal.duplicate()
	hover.bg_color = Color(color.r, color.g, color.b, 0.8)
	
	var pressed = normal.duplicate()
	pressed.bg_color = color.darkened(0.2)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

func _on_et_quiz_started(_data: Dictionary) -> void:
	if et_feedback_label:
		et_feedback_label.text = "LISTEN..."
		et_feedback_label.modulate = Color.WHITE
		_animate_feedback_pop()

func _on_et_quiz_answered(result: Dictionary) -> void:
	if et_feedback_label:
		if result.correct:
			et_feedback_label.text = "CORRECT!"
			et_feedback_label.modulate = Color("#55efc4")
		else:
			et_feedback_label.text = "TRY AGAIN"
			et_feedback_label.modulate = Color("#ff7675")
		_animate_feedback_pop()

func _animate_feedback_pop() -> void:
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	et_feedback_label.scale = Vector2(0.8, 0.8)
	tw.tween_property(et_feedback_label, "scale", Vector2(1, 1), 0.4)

# ============================================================
# OVERLAYS
# ============================================================
func _show_example_manager_dialog(semitones: int) -> void:
	pending_manage_interval = semitones
	if not example_manager_root: _create_example_manager_ui()
	_refresh_example_list()
	example_manager_root.visible = true

func _create_example_manager_ui() -> void:
	example_manager_root = Control.new()
	example_manager_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_parent().add_child(example_manager_root)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: example_manager_root.visible = false)
	example_manager_root.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	example_manager_root.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 300)
	center.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin = MarginContainer.new()
	for m in ["top", "left", "right", "bottom"]: margin.add_theme_constant_override("margin_" + m, 16)
	panel.add_child(margin)
	margin.add_child(vbox)
	var head = HBoxContainer.new()
	vbox.add_child(head)
	var title = Label.new()
	title.text = "Manage Examples"
	title.theme_type_variation = "HeaderMedium"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn = Button.new()
	close_btn.text = "✖"
	close_btn.flat = true
	close_btn.pressed.connect(func(): example_manager_root.visible = false)
	head.add_child(close_btn)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	example_list_box = VBoxContainer.new()
	example_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(example_list_box)
	var imp = Button.new()
	imp.text = "+ Import Song"
	imp.pressed.connect(_show_song_import_dialog)
	vbox.add_child(imp)

func _refresh_example_list() -> void:
	if not example_list_box: return
	for child in example_list_box.get_children(): child.queue_free()
	var riff_manager = _get_riff_manager()
	if not riff_manager: return
	var riffs = riff_manager.get_riffs_for_interval(pending_manage_interval)
	if riffs.is_empty():
		var lbl = Label.new()
		lbl.text = "No examples yet."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		example_list_box.add_child(lbl)
		return
	for i in riffs.size():
		var riff = riffs[i]
		var hbox = HBoxContainer.new()
		example_list_box.add_child(hbox)
		var play = Button.new()
		play.text = "▶"
		play.flat = true
		play.pressed.connect(func(): QuizManager.play_riff_preview(riff))
		hbox.add_child(play)
		var lbl = Label.new()
		lbl.text = riff.get("title", "Untitled")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)
		if riff.get("source") in ["user_import", "user"]:
			var del = Button.new()
			del.text = "🗑"
			del.flat = true
			del.pressed.connect(func(): riff_manager.delete_riff(pending_manage_interval, i, "interval"); _refresh_example_list())
			hbox.add_child(del)

func _show_song_import_dialog() -> void:
	if not import_overlay: _create_import_ui()
	import_option_button.clear()
	var sm = GameManager.get_node_or_null("SongManager")
	if sm:
		var songs = sm.get_song_list()
		for s in songs: import_option_button.add_item(s.get("title", "Untitled"))
	import_option_button.disabled = import_option_button.item_count == 0
	import_btn_ref.disabled = import_option_button.disabled
	import_overlay.visible = true

func _create_import_ui() -> void:
	import_overlay = Control.new()
	import_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_parent().add_child(import_overlay)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: import_overlay.visible = false)
	import_overlay.add_child(dim)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 200)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	import_overlay.add_child(center)
	center.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin = MarginContainer.new()
	for m in ["top", "left", "right", "bottom"]: margin.add_theme_constant_override("margin_" + m, 16)
	panel.add_child(margin)
	margin.add_child(vbox)
	var title = Label.new()
	title.text = "Import Song"
	title.theme_type_variation = "HeaderMedium"
	vbox.add_child(title)
	import_option_button = OptionButton.new()
	vbox.add_child(import_option_button)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(hbox)
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.flat = true
	cancel.pressed.connect(func(): import_overlay.visible = false)
	hbox.add_child(cancel)
	import_btn_ref = Button.new()
	import_btn_ref.text = "Import"
	import_btn_ref.pressed.connect(_on_import_confirmed)
	hbox.add_child(import_btn_ref)

func _on_import_confirmed() -> void:
	if import_option_button.selected == -1: return
	var title = import_option_button.get_item_text(import_option_button.selected)
	import_overlay.visible = false
	var rm = _get_riff_manager()
	if rm and rm.import_song_as_riff(pending_manage_interval, title):
		_refresh_example_list()
		pending_delete_song = title
		_show_delete_prompt(title)

func _show_delete_prompt(title: String) -> void:
	if not delete_overlay: _create_delete_ui()
	delete_label_ref.text = "Import successful!\n\nDelete '%s' from Library?" % title
	delete_overlay.visible = true

func _create_delete_ui() -> void:
	delete_overlay = Control.new()
	delete_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_parent().add_child(delete_overlay)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_overlay.add_child(dim)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 180)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_overlay.add_child(center)
	center.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin = MarginContainer.new()
	for m in ["top", "left", "right", "bottom"]: margin.add_theme_constant_override("margin_" + m, 16)
	panel.add_child(margin)
	margin.add_child(vbox)
	delete_label_ref = Label.new()
	delete_label_ref.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(delete_label_ref)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)
	var keep = Button.new()
	keep.text = "Keep"
	keep.flat = true
	keep.pressed.connect(func(): delete_overlay.visible = false)
	hbox.add_child(keep)
	var del = Button.new()
	del.text = "Delete"
	del.pressed.connect(func():
		var sm = GameManager.get_node_or_null("SongManager")
		if sm: sm.delete_song(pending_delete_song)
		delete_overlay.visible = false
	)
	hbox.add_child(del)

func _get_riff_manager() -> Node:
	var rm = get_tree().root.find_child("RiffManager", true, false)
	if not rm and GameManager.has_node("RiffManager"): rm = GameManager.get_node("RiffManager")
	return rm
