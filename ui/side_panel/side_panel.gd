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

var interval_tab = preload("res://ui/side_panel/tabs/interval_tab.gd")
var chord_tab = preload("res://ui/side_panel/tabs/chord_tab.gd")
var progression_tab = preload("res://ui/side_panel/tabs/progression_tab.gd")

var interval_controller: ETIntervalTab # Using specific types
var chord_controller: ETChordTab
var progression_controller: ETProgressionTab

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
	
	_setup_stage_button(et_replay_btn, ThemeColors.NEUTRAL.darkened(0.2))
	_setup_stage_button(et_next_btn, ThemeColors.TOGGLE_ON)
	
	interval_controller = interval_tab.new(self)
	chord_controller = chord_tab.new(self)
	progression_controller = progression_tab.new(self)
	
	interval_controller.setup()
	chord_controller.setup()
	progression_controller.setup()
	
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
	if not QuizManager.quiz_sequence_playing.is_connected(_on_et_quiz_sequence_playing): # [New] Listen for playback
		QuizManager.quiz_sequence_playing.connect(_on_et_quiz_sequence_playing)
	
	GameLogger.info("[SidePanel] Content build finished.")

func _on_et_quiz_sequence_playing(step_idx: int) -> void:
	if _active_tab_type != QuizManager.QuizType.CHORD_PROGRESSION: return
	if not progression_slots_container: return
	
	var slots = progression_slots_container.get_children()
	if step_idx >= 0 and step_idx < slots.size():
		var slot = slots[step_idx] as Control
		if progression_controller:
			progression_controller.animate_slot_pulse(slot) # [New] Custom pulse animation during playback

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
			lbl.modulate = ThemeColors.SUCCESS
			
			if progression_controller:
				progression_controller.animate_slot_pop(slot)
				progression_controller.update_progression_slots_active(data.step)
			
	else:
		# Wrong feedback - shake the current target slot
		var target_idx = data.step # The index the user WAS trying to fill
		if target_idx >= 0 and target_idx < slots.size() and progression_controller:
			progression_controller.animate_slot_shake(slots[target_idx])
		
		if et_feedback_label:
			et_feedback_label.text = "TRY AGAIN"
			et_feedback_label.modulate = ThemeColors.ERROR
			_animate_feedback_pop()
			et_feedback_label.modulate = ThemeColors.ERROR

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
# SHARED TAB UI UTILS
# ============================================================

func _update_tile_style(btn: Button, color: Color, is_active: bool) -> void:
	if not btn: return
	
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

func _setup_mode_button(btn: Button, text: String, mode_id: int, color: Color, pos_idx: int) -> void:
	if not btn: return
	
	btn.text = text
	btn.button_pressed = (mode_id in QuizManager.active_modes)
	
	btn.toggled.connect(func(on):
		if interval_controller:
			interval_controller._on_et_mode_toggled(on, mode_id)
		_update_mode_button_style(btn, color, on, pos_idx)
	)
	
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	_update_mode_button_style(btn, color, btn.button_pressed, pos_idx)

func _update_mode_button_style(btn: Button, color: Color, is_active: bool, pos_idx: int) -> void:
	if not btn: return
	
	var style = StyleBoxFlat.new()
	
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
		style.bg_color = Color(0, 0, 0, 0.03)
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
			style.bg_color = ThemeColors.SLOT_FUTURE_BG
			style.set_border_width_all(2)
			style.border_color = ThemeColors.SLOT_FUTURE_BORDER
			style.set_corner_radius_all(6)
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 4
			style.content_margin_bottom = 4
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
		if progression_controller:
			progression_controller.update_progression_slots_active(0)

func _on_et_quiz_answered(result: Dictionary) -> void:
	if et_feedback_label:
		if result.correct:
			et_feedback_label.text = "CORRECT!"
			et_feedback_label.modulate = ThemeColors.SUCCESS
		elif result.get("partial", false):
			et_feedback_label.text = "%d / %d Found" % [result.found_count, result.total_count]
			et_feedback_label.modulate = ThemeColors.PROGRESS # Light Blue for progress
		else:
			et_feedback_label.text = "TRY AGAIN"
			et_feedback_label.modulate = ThemeColors.ERROR
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
		style.bg_color = ThemeColors.TOGGLE_ON
		btn.add_theme_color_override("font_color", ThemeColors.TOGGLE_TEXT_ON)
	else:
		style.bg_color = ThemeColors.TOGGLE_OFF
		btn.add_theme_color_override("font_color", ThemeColors.TOGGLE_TEXT_OFF)
		
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
