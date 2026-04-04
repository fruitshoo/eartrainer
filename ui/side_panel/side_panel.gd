# side_panel.gd
# 사이드 패널 UI 컨트롤러 - 이어 트레이닝 전용
class_name SidePanel
extends BaseSidePanel

# ============================================================
# CONSTANTS & RESOURCES
# ============================================================
const ET_ROW_SCENE = preload("res://ui/side_panel/ear_trainer_item_row.tscn")
const SIDE_PANEL_STYLES = preload("res://ui/side_panel/side_panel_styles.gd")
const SIDE_PANEL_OVERLAYS = preload("res://ui/side_panel/side_panel_overlays.gd")
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
@onready var stage_panel: PanelContainer = %StagePanel
@onready var stage_margin: MarginContainer = %StageMargin
@onready var stage_buttons_hbox: HBoxContainer = %StageButtonsHBox
@onready var setup_toggle_btn: Button = %SetupToggleBtn
@onready var tabs_margin: MarginContainer = %TabsMargin
@onready var easy_margin: MarginContainer = %EasyMargin

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
var _active_tab_type: QuizManager.QuizType = QuizManager.QuizType.INTERVAL
var _trainer_setup_open: bool = true

var interval_tab = preload("res://ui/side_panel/tabs/interval_tab.gd")
var chord_tab = preload("res://ui/side_panel/tabs/chord_tab.gd")
var progression_tab = preload("res://ui/side_panel/tabs/progression_tab.gd")

var interval_controller: ETIntervalTab # Using specific types
var chord_controller: ETChordTab
var progression_controller: ETProgressionTab

var _side_panel_style_helper: SidePanelStyles
var _overlay_helper: SidePanelOverlays

func _get_panel_width() -> float:
	var viewport_width = get_viewport_rect().size.x
	return clampf(viewport_width * 0.38, 340.0, 440.0)

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	if _side_panel_style_helper == null:
		_side_panel_style_helper = SIDE_PANEL_STYLES.new(self)
	if _overlay_helper == null:
		_overlay_helper = SIDE_PANEL_OVERLAYS.new(self)
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

	if et_feedback_label:
		et_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		et_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		et_feedback_label.modulate = ThemeColors.APP_TEXT
		
	et_replay_btn.pressed.connect(QuizManager.replay_current_quiz)
	et_next_btn.pressed.connect(_on_next_pressed)
	if setup_toggle_btn:
		setup_toggle_btn.pressed.connect(_toggle_setup_visibility)
	
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
	_apply_workspace_layout()

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

func set_embedded_mode(enabled: bool) -> void:
	super.set_embedded_mode(enabled)
	_apply_workspace_layout()

func set_open(do_open: bool) -> void:
	if is_open != do_open:
		super.set_open(do_open)
		
		if not do_open:
			QuizManager.stop_quiz()
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner and is_ancestor_of(focus_owner):
				focus_owner.release_focus()

func _toggle_setup_visibility() -> void:
	_trainer_setup_open = not _trainer_setup_open
	_apply_setup_visibility()

func _apply_workspace_layout() -> void:
	if not is_node_ready():
		return
	if is_embedded:
		_trainer_setup_open = false if not is_open else _trainer_setup_open
		if stage_margin:
			stage_margin.add_theme_constant_override("margin_top", 8)
			stage_margin.add_theme_constant_override("margin_bottom", 10)
		if main_vbox:
			main_vbox.add_theme_constant_override("separation", 8)
	else:
		_trainer_setup_open = true
		if stage_margin:
			stage_margin.add_theme_constant_override("margin_top", 16)
			stage_margin.add_theme_constant_override("margin_bottom", 16)
		if main_vbox:
			main_vbox.add_theme_constant_override("separation", 0)
	_apply_setup_visibility()

func _apply_setup_visibility() -> void:
	if setup_toggle_btn:
		setup_toggle_btn.visible = is_embedded
		setup_toggle_btn.text = "OPTIONS" if not _trainer_setup_open else "HIDE"
	if tabs_margin:
		tabs_margin.visible = _trainer_setup_open or not is_embedded
	if easy_margin:
		easy_margin.visible = _trainer_setup_open or not is_embedded
	if stage_panel:
		stage_panel.custom_minimum_size.y = 88 if is_embedded else 120

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
	_side_panel_style_helper.update_tile_style(btn, color, is_active)

func _setup_mode_button(btn: Button, text: String, mode_id: int, color: Color, pos_idx: int) -> void:
	_side_panel_style_helper.setup_mode_button(btn, text, mode_id, color, pos_idx)

func _update_mode_button_style(btn: Button, color: Color, is_active: bool, pos_idx: int) -> void:
	_side_panel_style_helper.update_mode_button_style(btn, color, is_active, pos_idx)

func _setup_stage_button(btn: Button, color: Color) -> void:
	_side_panel_style_helper.setup_stage_button(btn, color)

func _on_et_quiz_started(data: Dictionary) -> void:
	if et_feedback_label:
		if data.get("type") == "interval" and data.get("beginner_mode", false):
			et_feedback_label.text = data.get("lesson_prompt", "LISTEN...")
		else:
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
			lbl.modulate = ThemeColors.APP_TEXT_MUTED
			slot_panel.add_child(lbl)
			
			progression_slots_container.add_child(slot_panel)
			
			# Add a 'ghost' index for current step tracking
			slot_panel.set_meta("slot_index", i)
			
		# Highlight first slot
		if progression_controller:
			progression_controller.update_progression_slots_active(0)

func _on_et_quiz_answered(result: Dictionary) -> void:
	if et_feedback_label:
		if result.get("partial", false):
			et_feedback_label.text = "%d / %d Found" % [result.found_count, result.total_count]
			et_feedback_label.modulate = ThemeColors.PROGRESS # Light Blue for progress
		elif result.get("beginner_mode", false):
			var lesson_text = "%s • %s" % [result.get("interval_short", "?"), result.get("shape_hint", "")]
			if result.correct:
				et_feedback_label.text = lesson_text
				et_feedback_label.modulate = ThemeColors.SUCCESS
			elif result.get("beginner_reveal", false):
				et_feedback_label.text = "Try %s" % lesson_text
				et_feedback_label.modulate = ThemeColors.PROGRESS
			else:
				et_feedback_label.text = "TRY AGAIN"
				et_feedback_label.modulate = ThemeColors.ERROR
		elif result.correct:
			et_feedback_label.text = "CORRECT!"
			et_feedback_label.modulate = ThemeColors.SUCCESS
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
		style.bg_color = ThemeColors.APP_BUTTON_BG_ACTIVE
		style.border_color = ThemeColors.APP_BUTTON_BORDER_ACTIVE
		btn.add_theme_color_override("font_color", ThemeColors.APP_TEXT)
	else:
		style.bg_color = ThemeColors.APP_BUTTON_BG
		style.border_color = ThemeColors.APP_BUTTON_BORDER
		btn.add_theme_color_override("font_color", ThemeColors.APP_TEXT_MUTED)
		
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


# Overlays logic kept as is but adapted parent calls if needed
# ... (Overlay methods _show_example_manager_dialog etc. - COPY THESE)
# To save space, I will assume the user has the overlay logic.
# I will output the FULL file content including overlays.

func _show_example_manager_dialog(semitones: int) -> void:
	_overlay_helper.show_example_manager_dialog(semitones)

func _create_example_manager_ui() -> void:
	pass

func _refresh_example_list() -> void:
	pass

func _show_song_import_dialog() -> void:
	_overlay_helper.show_song_import_dialog()

func _create_import_ui() -> void:
	pass

func _on_import_confirmed() -> void:
	pass

func _show_delete_prompt(title: String) -> void:
	_overlay_helper.show_delete_prompt(title)

func _create_delete_ui() -> void:
	pass

func _get_riff_manager() -> Node:
	return _overlay_helper.get_riff_manager()
