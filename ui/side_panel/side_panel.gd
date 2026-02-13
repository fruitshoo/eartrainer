# side_panel.gd
# 사이드 패널 UI 컨트롤러 - 이어 트레이닝 전용
class_name SidePanel
extends BaseSidePanel

# ============================================================
# CONSTANTS & RESOURCES
# ============================================================
const ET_ROW_SCENE = preload("res://ui/side_panel/ear_trainer_item_row.tscn")
var _main_theme: Theme = preload("res://ui/resources/main_theme.tres")

# ============================================================
# UI REFERENCES
# ============================================================
# UI References (Scene)
@onready var et_feedback_label: Label = %FeedbackLabel
@onready var et_replay_btn: Button = %ReplayBtn
@onready var et_next_btn: Button = %NextBtn
@onready var et_asc_mode: Button = %AscModeBtn
@onready var et_desc_mode: Button = %DescModeBtn
@onready var et_harm_mode: Button = %HarmModeBtn
@onready var et_interval_grid: GridContainer = %IntervalGrid
@onready var et_easy_mode: CheckBox = %EasyModeCheckbox
@onready var _scene_scroll: ScrollContainer = %ContentScroll

# State
var is_active: bool = false # Is quiz currently running?
var et_checkboxes: Dictionary = {} # semitones -> tile
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
	# BaseSidePanel calls _build_content
	# We need to do extra setup after UI is built
	super._ready()
	
	# 3. EventBus
	EventBus.request_collapse_side_panel.connect(close)
	
	# 4. Inits
	_populate_et_grid()
	_sync_et_state()

# ============================================================
# VIRTUAL METHODS
# ============================================================
func _build_content() -> void:
	GameLogger.info("[SidePanel] Building content...")
	
	# 1. Integrate Scene UI into BaseSidePanel
	if _scene_scroll:
		var old_parent = _scene_scroll.get_parent()
		if old_parent:
			old_parent.remove_child(_scene_scroll)
			_content_container.add_child(_scene_scroll)
	else:
		GameLogger.error("[SidePanel] _scene_scroll is NULL! Check TSCN structure.")
		
	# 2. Setup Signal Connections for Scene Nodes
	# We use clean assignments; if nodes are missing, log a single warning instead of many
	if not et_replay_btn or not et_next_btn:
		GameLogger.error("[SidePanel] Core buttons missing from scene!")
		return
		
	et_replay_btn.pressed.connect(QuizManager.play_current_interval)
	et_next_btn.pressed.connect(QuizManager.start_interval_quiz)
	
	_setup_stage_button(et_replay_btn, Color("#34495e"))
	_setup_stage_button(et_next_btn, Color("#3498db"))
	
	if et_asc_mode: _setup_mode_button(et_asc_mode, "↗", QuizManager.IntervalMode.ASCENDING, Color("#81ecec"), 0)
	if et_desc_mode: _setup_mode_button(et_desc_mode, "↘", QuizManager.IntervalMode.DESCENDING, Color("#fab1a0"), 1)
	if et_harm_mode: _setup_mode_button(et_harm_mode, "≡", QuizManager.IntervalMode.HARMONIC, Color("#ffeaa7"), 2)
	
	if et_easy_mode:
		et_easy_mode.toggled.connect(func(v): GameManager.show_target_visual = v)
		et_easy_mode.button_pressed = GameManager.show_target_visual
	
	QuizManager.quiz_started.connect(_on_et_quiz_started)
	QuizManager.quiz_answered.connect(_on_et_quiz_answered)
	
	GameLogger.info("[SidePanel] Content build finished.")

# ============================================================
# PUBLIC API WRAPPERS
# ============================================================
func toggle() -> void:
	set_open(not is_open)

func set_open(do_open: bool) -> void:
	if is_open != do_open:
		super.set_open(do_open)
		
		if not do_open:
			QuizManager.stop_quiz()
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner and is_ancestor_of(focus_owner):
				focus_owner.release_focus()

func _input(event: InputEvent) -> void:
	# Base handles cancel
	super._input(event)
	
	# [Refinement] Removed manual mouse wheel blocking.
	# The BaseSidePanel or Control nodes should handle this naturally.
	# Blocking it here was preventing the ScrollContainer from receiving events.

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

func _setup_mode_button(btn: Button, text: String, mode_id: int, color: Color, pos_idx: int) -> void:
	btn.text = text
	btn.button_pressed = (mode_id in QuizManager.active_modes)
	
	# Connect toggled signal
	btn.toggled.connect(func(on):
		_on_et_mode_toggled(on, mode_id)
		_update_mode_button_style(btn, color, on, pos_idx)
	)
	
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	_update_mode_button_style(btn, color, btn.button_pressed, pos_idx)

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


# Overlays logic kept as is but adapted parent calls if needed
# ... (Overlay methods _show_example_manager_dialog etc. - COPY THESE)
# To save space, I will assume the user has the overlay logic.
# I will output the FULL file content including overlays.

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
