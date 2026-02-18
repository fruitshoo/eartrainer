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
@onready var main_vbox: VBoxContainer = %MainVBox
@onready var tabs_hbox: HBoxContainer = %TabsHBox

# [New] Tab System
@onready var tab_interval_btn: Button = %TabIntervalBtn
@onready var tab_chord_btn: Button = %TabChordBtn
var tab_prog_btn: Button # [New] Dynamically created in _ready
@onready var tab_scale_btn: Button = %TabScaleBtn
@onready var tab_pitch_btn: Button = %TabPitchBtn

@onready var interval_container: VBoxContainer = %IntervalContainer
@onready var chord_container: VBoxContainer = %ChordContainer
@onready var scale_container: VBoxContainer = %ScaleContainer
@onready var pitch_container: VBoxContainer = %PitchContainer
# [New] Progression Container
var progression_container: VBoxContainer = null
var progression_slots_container: HBoxContainer = null

# [New] Chord Training UI
@onready var chord_type_grid: GridContainer = %ChordTypeGrid
@onready var chord_up_btn: Button = %ChordUpBtn
@onready var chord_down_btn: Button = %ChordDownBtn
@onready var chord_harm_btn: Button = %ChordHarmBtn
@onready var chord_inv_root_btn: Button = %ChordInvRootBtn
@onready var chord_inv_1st_btn: Button = %ChordInv1stBtn
@onready var chord_inv_2nd_btn: Button = %ChordInv2ndBtn
var chord_location_toggle: CheckButton
var chord_voicing_toggle_theory: Button
var chord_voicing_toggle_form: Button

# State
var is_active: bool = false # Is quiz currently running?
var et_checkboxes: Dictionary = {} # semitones -> tile
var pending_manage_interval: int = -1
var pending_delete_song: String = ""
var _active_tab_type: QuizManager.QuizType = QuizManager.QuizType.INTERVAL
var _prog_degree_btns: Array[Button] = [] # [New] Track filter buttons

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
	
	# EventBus connections
	EventBus.request_collapse_side_panel.connect(close)
	
	# Inits
	_populate_et_grid()
	_populate_chord_grid()
	_sync_et_state()
	_sync_chord_state()
	
	# [New] Setup progression tab UI dynamically
	_setup_progression_tab_ui()
	
	# Initial State - Set UI but DON'T auto-start quiz on launch
	_set_active_tab(QuizManager.QuizType.INTERVAL, false)

# ============================================================
# VIRTUAL METHODS
# ============================================================
func _build_content() -> void:
	GameLogger.info("[SidePanel] Building content...")
	
	# [Fix] Initialize dynamic tab buttons BEFORE they are used in connections below
	if not tab_prog_btn:
		tab_prog_btn = Button.new()
	
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
		
	et_replay_btn.pressed.connect(QuizManager.replay_current_quiz)
	et_next_btn.pressed.connect(_on_next_pressed)
	
	# [New] Tab Logic
	tab_interval_btn.pressed.connect(func(): _set_active_tab(QuizManager.QuizType.INTERVAL))
	tab_chord_btn.pressed.connect(func(): _set_active_tab(QuizManager.QuizType.CHORD_QUALITY))
	tab_prog_btn.pressed.connect(func(): _set_active_tab(QuizManager.QuizType.CHORD_PROGRESSION)) # [New]
	tab_scale_btn.pressed.connect(func(): _set_active_tab(QuizManager.QuizType.NONE)) # Placeholder for Scale
	tab_pitch_btn.pressed.connect(func(): _set_active_tab(QuizManager.QuizType.PITCH_CLASS))
	
	_update_tab_buttons_visuals()
	
	_setup_stage_button(et_replay_btn, Color("#34495e"))
	_setup_stage_button(et_next_btn, Color("#3498db"))
	
	if et_asc_mode: _setup_mode_button(et_asc_mode, "↗", QuizManager.IntervalMode.ASCENDING, Color("#81ecec"), 0)
	if et_desc_mode: _setup_mode_button(et_desc_mode, "↘", QuizManager.IntervalMode.DESCENDING, Color("#fab1a0"), 1)
	if et_harm_mode: _setup_mode_button(et_harm_mode, "≡", QuizManager.IntervalMode.HARMONIC, Color("#ffeaa7"), 2)
	
	# [New] Chord Direction Buttons
	_setup_chord_dir_button(chord_up_btn, "↑", 0, Color("#81ecec"), 0)
	_setup_chord_dir_button(chord_down_btn, "↓", 1, Color("#fab1a0"), 1)
	_setup_chord_dir_button(chord_harm_btn, "≡", 2, Color("#ffeaa7"), 2)
	
	# [New] Chord Inversion Buttons
	_setup_chord_inv_button(chord_inv_root_btn, "Root", 0, Color("#74b9ff"), 0)
	_setup_chord_inv_button(chord_inv_1st_btn, "1st", 1, Color("#a29bfe"), 1)
	_setup_chord_inv_button(chord_inv_2nd_btn, "2nd", 2, Color("#81ecec"), 2)
	
	# [New] Voicing Mode Toggle
	_setup_voicing_toggle()
	
	# [Fix] Ensure tab buttons fit the panel width
	tab_interval_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_chord_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_prog_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL # [New]
	tab_scale_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_pitch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	tab_interval_btn.custom_minimum_size.x = 0
	tab_chord_btn.custom_minimum_size.x = 0
	tab_prog_btn.custom_minimum_size.x = 0 # [New]
	tab_scale_btn.custom_minimum_size.x = 0
	tab_pitch_btn.custom_minimum_size.x = 0
	
	# [New] Listen for quiz steps
	if not QuizManager.quiz_step_completed.is_connected(_on_et_quiz_step):
		QuizManager.quiz_step_completed.connect(_on_et_quiz_step)
	
	QuizManager.quiz_started.connect(_on_et_quiz_started)
	QuizManager.quiz_answered.connect(_on_et_quiz_answered)
	
	GameLogger.info("[SidePanel] Content build finished.")

func _on_et_quiz_step(data: Dictionary) -> void:
	if not progression_slots_container: return
	
	# data: {step, total, correct, degree}
	var slots = progression_slots_container.get_children()
	var idx = data.step - 1 # 0-based
	
	if data.correct:
		if idx >= 0 and idx < slots.size():
			var slot = slots[idx] as PanelContainer
			var lbl = slot.get_child(0) as Label
			lbl.text = _get_degree_text(data.degree)
			lbl.modulate = Color("#55efc4")
			
			_animate_slot_pop(slot)
			_update_progression_slots_active(data.step)
			
	else:
		# Wrong feedback - shake the current target slot
		var target_idx = data.step # The index the user WAS trying to fill
		if target_idx >= 0 and target_idx < slots.size():
			_animate_slot_shake(slots[target_idx])
		
		if et_feedback_label:
			et_feedback_label.text = "TRY AGAIN"
			et_feedback_label.modulate = Color("#ff7675")
			_animate_feedback_pop()
			et_feedback_label.modulate = Color("#ff7675")

func _get_degree_text(degree: int) -> String:
	var texts = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
	if degree >= 0 and degree < texts.size():
		return texts[degree]
	return "?"

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

	# [New] Interval Options UI
	_setup_interval_options_ui()

func _setup_interval_options_ui() -> void:
	# [Fix] Options should be in the main VBox (interval_container), NOT inside the GridMargin (which overlaps children)
	# 1. Cleanup: Remove from wrong parent if it exists (old buggy version)
	var wrong_parent = et_interval_grid.get_parent()
	if wrong_parent and wrong_parent.has_node("IntervalOptions"):
		wrong_parent.get_node("IntervalOptions").queue_free()
		
	# 2. Cleanup: Remove existing valid container to rebuild (simpler than update)
	if interval_container.has_node("IntervalOptionsPad"):
		interval_container.get_node("IntervalOptionsPad").queue_free()
	
	# 3. Create new structure: Pad (Margin) -> Options (VBox)
	var options_container = VBoxContainer.new()
	options_container.name = "IntervalOptions"
	options_container.add_theme_constant_override("separation", 8)
	
	var pad = MarginContainer.new()
	pad.name = "IntervalOptionsPad"
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.add_child(options_container)
	
	interval_container.add_child(pad)
	# [New] Move to TOP of list
	interval_container.move_child(pad, 0)
	
	# 4. Populate Options
	
	# Row 1: Toggles (Diatonic + Context)
	var toggles_hbox = HBoxContainer.new()
	toggles_hbox.add_theme_constant_override("separation", 16)
	
	# Diatonic Mode Toggle
	var diatonic_check = CheckBox.new()
	diatonic_check.text = "Diatonic"
	diatonic_check.tooltip_text = "Only generate intervals that naturally occur within the current key's scale."
	diatonic_check.button_pressed = QuizManager.interval_diatonic_mode
	diatonic_check.focus_mode = Control.FOCUS_NONE
	diatonic_check.toggled.connect(func(on):
		QuizManager.interval_diatonic_mode = on
		QuizManager.save_interval_settings()
	)
	toggles_hbox.add_child(diatonic_check)
	
	# Harmonic Context Toggle
	var context_check = CheckBox.new()
	context_check.text = "Context"
	context_check.tooltip_text = "Play the tonic chord (I) before the quiz starts."
	context_check.button_pressed = QuizManager.interval_harmonic_context
	context_check.focus_mode = Control.FOCUS_NONE
	context_check.toggled.connect(func(on):
		QuizManager.interval_harmonic_context = on
		QuizManager.save_interval_settings()
	)
	toggles_hbox.add_child(context_check)
	
	options_container.add_child(toggles_hbox)
	
	# Row 2: String Constraint Dropdown
	var string_hbox = HBoxContainer.new()
	var string_label = Label.new()
	string_label.text = "Strings:"
	string_hbox.add_child(string_label)
	
	var string_opt = OptionButton.new()
	string_opt.tooltip_text = "Restrict where notes can appear:\n- All: Any string\n- Same: Both notes on same string (Distance)\n- Cross: Adjacent strings (Shapes)"
	string_opt.focus_mode = Control.FOCUS_NONE
	string_opt.add_item("All Strings", 0)
	string_opt.add_item("Same String", 1)
	string_opt.add_item("Cross String", 2)
	string_opt.selected = QuizManager.interval_string_constraint
	string_opt.item_selected.connect(func(idx):
		QuizManager.interval_string_constraint = idx
		QuizManager.save_interval_settings()
	)
	string_hbox.add_child(string_opt)
	options_container.add_child(string_hbox)
	
	# Separator
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

# [New] Degree-based Chord Training
func _populate_chord_grid() -> void:
	if not chord_type_grid: return
	for child in chord_type_grid.get_children(): child.queue_free()
	
	# Build 7 diatonic degree tiles
	for degree_idx in range(7):
		var chord_data = MusicTheory.get_chord_from_degree(GameManager.current_mode, degree_idx)
		if chord_data.is_empty(): continue
		
		var roman = chord_data[2] # e.g. "I", "ii", "iii", etc.
		var is_active = degree_idx in QuizManager.active_degrees
		var tile = _create_degree_tile(degree_idx, roman, is_active)
		chord_type_grid.add_child(tile)

func _create_degree_tile(degree_idx: int, label: String, is_checked: bool) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(50, 50)
	btn.add_theme_font_size_override("font_size", 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_checked
	
	_update_tile_style(btn, Color("#3498db"), is_checked)
	
	btn.toggled.connect(func(on):
		if on:
			if not degree_idx in QuizManager.active_degrees: QuizManager.active_degrees.append(degree_idx)
		else:
			QuizManager.active_degrees.erase(degree_idx)
			# Prevent empty selection
			if QuizManager.active_degrees.is_empty():
				QuizManager.active_degrees.append(degree_idx)
				btn.set_pressed_no_signal(true)
		_update_tile_style(btn, Color("#3498db"), btn.button_pressed)
		QuizManager.save_chord_settings()
	)
	return btn

func _sync_chord_state() -> void:
	# [Fix #5] Direction uses active_directions array
	var dir_list = QuizManager.active_directions
	_update_chord_dir_style(chord_up_btn, Color("#81ecec"), 0 in dir_list, 0)
	_update_chord_dir_style(chord_down_btn, Color("#fab1a0"), 1 in dir_list, 1)
	_update_chord_dir_style(chord_harm_btn, Color("#ffeaa7"), 2 in dir_list, 2)
	
	var inv_list = QuizManager.active_inversions
	_update_chord_inv_style(chord_inv_root_btn, Color("#74b9ff"), 0 in inv_list, 0)
	_update_chord_inv_style(chord_inv_1st_btn, Color("#a29bfe"), 1 in inv_list, 1)
	_update_chord_inv_style(chord_inv_2nd_btn, Color("#81ecec"), 2 in inv_list, 2)
	
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
	_update_mode_button_style(btn, color, is_active, pos)

func _update_chord_inv_style(btn: Button, color: Color, is_active: bool, pos: int) -> void:
	_update_mode_button_style(btn, color, is_active, pos)

func _setup_voicing_toggle() -> void:
	# Create a horizontal container for the toggle
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 2)
	
	chord_voicing_toggle_theory = Button.new()
	chord_voicing_toggle_theory.text = "이론"
	chord_voicing_toggle_theory.custom_minimum_size = Vector2(60, 36)
	chord_voicing_toggle_theory.add_theme_font_size_override("font_size", 13)
	chord_voicing_toggle_theory.focus_mode = Control.FOCUS_NONE
	
	chord_voicing_toggle_form = Button.new()
	chord_voicing_toggle_form.text = "기타폼"
	chord_voicing_toggle_form.custom_minimum_size = Vector2(70, 36)
	chord_voicing_toggle_form.add_theme_font_size_override("font_size", 13)
	chord_voicing_toggle_form.focus_mode = Control.FOCUS_NONE
	
	hbox.add_child(chord_voicing_toggle_theory)
	hbox.add_child(chord_voicing_toggle_form)
	
	# Insert into chord_container (after chord_type_grid's parent)
	if chord_type_grid and chord_type_grid.get_parent():
		var parent = chord_type_grid.get_parent()
		var idx = chord_type_grid.get_index() + 1
		parent.add_child(hbox)
		parent.move_child(hbox, idx)
	
	chord_voicing_toggle_theory.pressed.connect(func():
		QuizManager.chord_quiz_use_voicing = false
		_update_voicing_toggle_style()
		QuizManager.save_chord_settings()
	)
	chord_voicing_toggle_form.pressed.connect(func():
		QuizManager.chord_quiz_use_voicing = true
		_update_voicing_toggle_style()
		QuizManager.save_chord_settings()
	)
	
	_update_voicing_toggle_style()

func _update_voicing_toggle_style() -> void:
	var is_voicing = QuizManager.chord_quiz_use_voicing
	_update_tile_style(chord_voicing_toggle_theory, Color("#74b9ff"), not is_voicing)
	_update_tile_style(chord_voicing_toggle_form, Color("#fdcb6e"), is_voicing)

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

func _on_et_quiz_started(data: Dictionary) -> void:
	if et_feedback_label:
		et_feedback_label.text = "LISTEN..."
		et_feedback_label.modulate = Color.WHITE
		_animate_feedback_pop()
		
	if data.get("type") == "progression":
		if not progression_slots_container: return
		# Setup slots
		for child in progression_slots_container.get_children(): child.queue_free()
		
		# [Fix] Box-style slots
		for i in range(data.length):
			var slot_panel = PanelContainer.new()
			var style = StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.1)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(1, 1, 1, 0.2)
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			slot_panel.add_theme_stylebox_override("panel", style)
			
			var lbl = Label.new()
			lbl.text = "?"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.modulate = Color(1, 1, 1, 0.5)
			slot_panel.add_child(lbl)
			
			progression_slots_container.add_child(slot_panel)
			
			# Add a 'ghost' index for current step tracking
			slot_panel.set_meta("slot_index", i)
			
		# Highlight first slot
		_update_progression_slots_active(0)

func _on_et_quiz_answered(result: Dictionary) -> void:
	if et_feedback_label:
		if result.correct:
			et_feedback_label.text = "CORRECT!"
			et_feedback_label.modulate = Color("#55efc4")
		elif result.get("partial", false):
			et_feedback_label.text = "%d / %d Found" % [result.found_count, result.total_count]
			et_feedback_label.modulate = Color("#74b9ff") # Light Blue for progress
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
# TAB SYSTEM LOGIC
# ============================================================
func _on_next_pressed() -> void:
	match _active_tab_type:
		QuizManager.QuizType.INTERVAL:
			QuizManager.start_interval_quiz()
		QuizManager.QuizType.CHORD_QUALITY:
			QuizManager.start_chord_quiz()
		QuizManager.QuizType.CHORD_PROGRESSION:
			QuizManager.start_progression_quiz()
		QuizManager.QuizType.PITCH_CLASS:
			QuizManager.start_pitch_quiz()
		_:
			QuizManager.start_interval_quiz() # Fallback


func _setup_progression_tab_ui() -> void:
	# 1. Add Tab Button
	# [Fix] tab_prog_btn is now initialized in _build_content correctly
	tab_prog_btn.text = "PROG"
	tab_prog_btn.toggle_mode = true
	tab_prog_btn.focus_mode = Control.FOCUS_NONE
	tab_prog_btn.custom_minimum_size.y = 40
	tabs_hbox.add_child(tab_prog_btn)
	tabs_hbox.move_child(tab_prog_btn, 2) # Insert after Chord
	
	# 2. Create Container
	progression_container = VBoxContainer.new()
	progression_container.name = "ProgressionContainer"
	progression_container.visible = false
	progression_container.add_theme_constant_override("separation", 16)
	main_vbox.add_child(progression_container)
	main_vbox.move_child(progression_container, chord_container.get_index() + 1)
	
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
	
	progression_slots_container = HBoxContainer.new()
	progression_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	progression_slots_container.add_theme_constant_override("separation", 10)
	slots_frame.add_child(progression_slots_container)
	
	progression_container.add_child(slots_frame)
	
	# 4. Input Buttons (I through vii) - NOW FILTERS
	var input_grid = GridContainer.new()
	input_grid.columns = 4
	input_grid.add_theme_constant_override("h_separation", 8)
	input_grid.add_theme_constant_override("v_separation", 8)
	
	var degrees = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
	_prog_degree_btns.clear()
	
	for i in range(degrees.size()):
		var btn = Button.new()
		btn.text = degrees[i]
		btn.custom_minimum_size = Vector2(0, 45)
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
		
	progression_container.add_child(input_grid)
	_update_degree_filter_visuals()

func _on_degree_filter_toggled(degree_idx: int, is_pressed: bool) -> void:
	var active = QuizManager.active_progression_degrees
	if is_pressed:
		if not degree_idx in active:
			active.append(degree_idx)
	else:
		active.erase(degree_idx)
	
	# Minimum 1 degree must be selected? 
	if active.is_empty():
		active.append(degree_idx)
		_prog_degree_btns[degree_idx].button_pressed = true
		
	_update_degree_filter_visuals()

func _update_degree_filter_visuals() -> void:
	for i in range(_prog_degree_btns.size()):
		var btn = _prog_degree_btns[i]
		var is_active = i in QuizManager.active_progression_degrees
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		if is_active:
			style.bg_color = Color("#4834d4") # Active filter color
			style.set_border_width_all(2)
			style.border_color = Color("#686de0")
		else:
			style.bg_color = Color(1, 1, 1, 0.05)
			style.set_border_width_all(1)
			style.border_color = Color(1, 1, 1, 0.1)
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _update_progression_slots_active(step_idx: int) -> void:
	var slots = progression_slots_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot is PanelContainer: continue
		
		var style = slot.get_theme_stylebox("panel").duplicate()
		if i == step_idx:
			style.border_color = Color("#74b9ff") # Active slot highlight
			style.bg_color = Color(1, 1, 1, 0.2)
			slot.modulate.a = 1.0
		elif i < step_idx:
			# Completed
			style.border_color = Color("#55efc4")
			style.bg_color = Color(1, 1, 1, 0.1)
			slot.modulate.a = 1.0
		else:
			# Future slots
			style.border_color = Color(1, 1, 1, 0.2)
			style.bg_color = Color(1, 1, 1, 0.05)
			slot.modulate.a = 0.5
		slot.add_theme_stylebox_override("panel", style)

func _animate_slot_pop(slot: Control) -> void:
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	slot.pivot_offset = slot.size / 2
	slot.scale = Vector2(0.8, 0.8)
	tw.tween_property(slot, "scale", Vector2(1, 1), 0.4)

func _animate_slot_shake(slot: Control) -> void:
	var tw = create_tween()
	var start_pos = slot.position
	tw.tween_property(slot, "position:x", start_pos.x + 10, 0.05)
	tw.tween_property(slot, "position:x", start_pos.x - 10, 0.05)
	tw.tween_property(slot, "position:x", start_pos.x + 10, 0.05)
	tw.tween_property(slot, "position:x", start_pos.x, 0.05)

func _set_active_tab(type: int, auto_start: bool = true) -> void: # QuizType
	_active_tab_type = type # [Fix] Sync state
	
	# Update visibility
	if interval_container: interval_container.visible = (type == QuizManager.QuizType.INTERVAL)
	if chord_container: chord_container.visible = (type == QuizManager.QuizType.CHORD_QUALITY)
	if scale_container: scale_container.visible = (type == QuizManager.QuizType.NONE)
	if pitch_container: pitch_container.visible = (type == QuizManager.QuizType.PITCH_CLASS)
	if progression_container: progression_container.visible = (type == QuizManager.QuizType.CHORD_PROGRESSION)
	
	_update_tab_buttons_visuals() # [Fix] Refresh styling
	
	# [Fix] Only start quiz if explicitly asked (not on startup)
	if not auto_start: return
	
	# Start Quiz Logic
	match type:
		QuizManager.QuizType.INTERVAL: QuizManager.start_interval_quiz()
		QuizManager.QuizType.CHORD_QUALITY: QuizManager.start_chord_quiz()
		QuizManager.QuizType.CHORD_PROGRESSION: QuizManager.start_progression_quiz()
		QuizManager.QuizType.PITCH_CLASS: QuizManager.start_pitch_quiz()


func _update_tab_buttons_visuals() -> void:
	_update_tab_btn_style(tab_interval_btn, _active_tab_type == QuizManager.QuizType.INTERVAL, 0)
	_update_tab_btn_style(tab_chord_btn, _active_tab_type == QuizManager.QuizType.CHORD_QUALITY, 1)
	_update_tab_btn_style(tab_prog_btn, _active_tab_type == QuizManager.QuizType.CHORD_PROGRESSION, 2)
	_update_tab_btn_style(tab_scale_btn, _active_tab_type == QuizManager.QuizType.NONE, 3)
	_update_tab_btn_style(tab_pitch_btn, _active_tab_type == QuizManager.QuizType.PITCH_CLASS, 4)

func _update_tab_btn_style(btn: Button, is_active: bool, pos: int) -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 10 if pos == 0 else 0
	style.corner_radius_top_right = 10 if pos == 4 else 0
	
	if is_active:
		style.bg_color = Color("#3498db")
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(0, 0, 0, 0.1)
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0.4))
		
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


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
