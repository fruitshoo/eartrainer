# side_panel.gd
# 사이드 패널 UI 컨트롤러 - 탭 전환, 설정/라이브러리/트레이닝
extends Control

# ============================================================
# SIGNALS
# ============================================================
signal tab_changed(tab_index: int)
signal toggled(is_open: bool)

# ============================================================
# ENUMS
# ============================================================
# enum SheetState {MINIMIZED, HALF, MAXIMIZED} # Deprecated
enum Tab {SETTINGS, LIBRARY, EAR_TRAINER}
enum LibraryTabMode {PRESETS, SONGS} # [New]

# ============================================================
# CONSTANTS
# ============================================================
const PANEL_WIDTH := 400.0
const TWEEN_DURATION := 0.3
const MARGIN_RIGHT := 16.0
const MARGIN_TOP := 20.0
const MARGIN_BOTTOM := 80.0
const DRAG_THRESHOLD := 50.0 # 스냅 임계값

var preset_item_scene: PackedScene = preload("res://ui/sequence/library_panel/preset_item.tscn")
var riff_editor_scene: PackedScene = preload("res://ui/side_panel/RiffEditor.tscn") # [New]

# ============================================================
# EXPORTS
# ============================================================
@export var tab_icons: Array[Texture2D] = []

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var tab_bar: HBoxContainer = %TabBar
@onready var content_container: Control = %ContentContainer

@onready var settings_tab: Button = %SettingsTab
@onready var library_tab: Button = %LibraryTab
@onready var ear_trainer_tab: Button = %EarTrainerTab

@onready var settings_content: Control = %SettingsContent
@onready var library_content: Control = %LibraryContent
@onready var ear_trainer_content: Control = %EarTrainerContent

# Settings Tab References
@onready var notation_option: OptionButton = %NotationOptionButton
@onready var note_label_check: CheckBox = %NoteLabelCheck
@onready var root_check: CheckBox = %RootCheck
@onready var chord_check: CheckBox = %ChordCheck
@onready var scale_check: CheckBox = %ScaleCheck

# Focus Range Controls
@onready var focus_minus_btn: Button = %MinusButton
@onready var focus_value_label: Label = %ValueLabel
@onready var focus_plus_btn: Button = %PlusButton

# Deadzone Controls
@onready var deadzone_minus_btn: Button = %DeadzoneMinus
@onready var deadzone_value_label: Label = %DeadzoneValue
@onready var deadzone_plus_btn: Button = %DeadzonePlus

# Library Tab References [New]
@onready var presets_tab_btn: Button = %PresetsTab
@onready var songs_tab_btn: Button = %SongsTab
@onready var preset_list_container: VBoxContainer = %PresetListContainer
@onready var library_name_input: LineEdit = %NameInput
@onready var library_save_btn: Button = %SaveButton

# Ear Trainer Tab References [New]
@onready var et_feedback_label: Label = %FeedbackLabel
@onready var et_asc_mode: CheckBox = %AscMode
@onready var et_desc_mode: CheckBox = %DescMode
@onready var et_harm_mode: CheckBox = %HarmMode
@onready var et_easy_mode: CheckBox = %EasyMode
@onready var et_interval_grid: GridContainer = %IntervalGrid
@onready var et_replay_btn: Button = %ReplayButton
@onready var et_next_btn: Button = %NextButton

# ============================================================
# STATE
# ============================================================
var is_open: bool = false
var current_tab: Tab = Tab.SETTINGS
var current_library_mode: LibraryTabMode = LibraryTabMode.PRESETS # [New]
var selected_library_item: String = "" # [New]

var _tween: Tween

# Ear Trainer State
var et_checkboxes: Dictionary = {} # [New]
const ET_ROW_SCENE = preload("res://ui/side_panel/EarTrainerItemRow.tscn") # [New]

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	# 초기 상태 설정: 닫힘 (화면 밖)
	_update_position(false)
	_switch_tab(Tab.SETTINGS, false)
	
	# 시그널 연결
	settings_tab.pressed.connect(func(): _switch_tab(Tab.SETTINGS))
	library_tab.pressed.connect(func(): _switch_tab(Tab.LIBRARY))
	ear_trainer_tab.pressed.connect(func(): _switch_tab(Tab.EAR_TRAINER))
	
	# [Fix] Prevent Spacebar from re-triggering tabs (re-opening panel)
	settings_tab.focus_mode = Control.FOCUS_NONE
	library_tab.focus_mode = Control.FOCUS_NONE
	ear_trainer_tab.focus_mode = Control.FOCUS_NONE
	
	# EventBus 연결
	EventBus.request_toggle_settings.connect(toggle)
	EventBus.request_show_side_panel_tab.connect(_on_request_show_tab)
	EventBus.request_collapse_side_panel.connect(close)
	EventBus.request_close_settings.connect(close)
	
	# Settings 초기화 (기존 코드 유지)
	_init_volume_settings() # [New]
	_init_settings_tab()
	_init_library_tab()
	_init_ear_trainer_tab()

func _init_volume_settings() -> void:
	# Check if Volume Section already exists to prevent duplication
	if settings_content.find_child("VolumeGrid", true, false):
		return
		
	var vbox = settings_content.find_child("SettingsVBox")
	if not vbox: return
	
	# Create Section Header
	var header = Label.new()
	header.text = "Volume"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.theme_type_variation = "HeaderSmall"
	vbox.add_child(header)
	vbox.move_child(header, 0) # Top of settings
	
	var grid = GridContainer.new()
	grid.name = "VolumeGrid"
	grid.columns = 2
	vbox.add_child(grid)
	vbox.move_child(grid, 1)
	
	var divider = HSeparator.new()
	vbox.add_child(divider)
	vbox.move_child(divider, 2)
	
	# Add Sliders
	_add_volume_slider(grid, "Master", "Master")
	_add_volume_slider(grid, "Chord", "Chord")
	_add_volume_slider(grid, "Melody", "Melody")
	_add_volume_slider(grid, "SFX", "SFX")

func _add_volume_slider(parent: Node, label_text: String, bus_name: String) -> void:
	var label = Label.new()
	label.text = label_text
	parent.add_child(label)
	
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(120, 0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Get current volume
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	
	slider.value_changed.connect(func(value):
		var idx = AudioServer.get_bus_index(bus_name)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(value))
			AudioServer.set_bus_mute(idx, value < 0.01)
			# Save? Later via GameManager
	)
	
	parent.add_child(slider)

func _on_request_show_tab(tab_index: int) -> void:
	var tab: Tab = tab_index as Tab
	show_tab(tab)

func toggle() -> void:
	set_open(not is_open)

func open() -> void:
	set_open(true)

func close() -> void:
	set_open(false)

func set_open(open: bool) -> void:
	if is_open != open:
		is_open = open
		_animate_slide(open)
		
		# [Auto-Stop] If closing Ear Trainer, stop quiz
		if not open and current_tab == Tab.EAR_TRAINER:
			QuizManager.stop_quiz()
		
		# [Fix] Release focus when closing to prevent lingering inputs (e.g. Spacebar triggers hidden buttons)
		if not open:
			# If a child of this panel has focus, release it
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner and is_ancestor_of(focus_owner):
				focus_owner.release_focus()
		
		toggled.emit(open)
		# 열릴 때 EventBus 등으로 알림 가능
		EventBus.settings_visibility_changed.emit(open)

# Position Update using Offsets (Anchor Right)
func _update_position(open: bool) -> void:
	if open:
		offset_left = - PANEL_WIDTH
		offset_right = 0
	else:
		offset_left = 0
		offset_right = PANEL_WIDTH
		
	# Height is handled by Anchor Bottom = 1.0 automatically.

func _animate_slide(open: bool) -> void:
	if _tween:
		_tween.kill()
	
	var target_l = - PANEL_WIDTH if open else 0.0
	var target_r = 0.0 if open else PANEL_WIDTH
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	_tween.tween_property(self, "offset_left", target_l, TWEEN_DURATION)
	_tween.tween_property(self, "offset_right", target_r, TWEEN_DURATION)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ============================================================
# TAB MANAGEMENT
# ============================================================
func _switch_tab(tab: Tab, animate: bool = true) -> void:
	if current_tab == tab and animate:
		# 같은 탭 클릭시 토글
		toggle()
		return
	
	# [Auto-Stop] If switching FROM Ear Trainer TO something else
	if current_tab == Tab.EAR_TRAINER and tab != Tab.EAR_TRAINER:
		QuizManager.stop_quiz()
	
	current_tab = tab
	
	# 탭 버튼 상태 업데이트
	settings_tab.button_pressed = (tab == Tab.SETTINGS)
	library_tab.button_pressed = (tab == Tab.LIBRARY)
	ear_trainer_tab.button_pressed = (tab == Tab.EAR_TRAINER)
	
	# 콘텐츠 전환
	_show_content(tab, animate)
	
	# 닫혀있으면 열기
	if not is_open and animate:
		open()
	
	tab_changed.emit(tab)

func _show_content(tab: Tab, animate: bool = true) -> void:
	var contents := [settings_content, library_content, ear_trainer_content]
	
	for i in range(contents.size()):
		var content: Control = contents[i]
		if content == null:
			continue
			
		if i == tab:
			content.visible = true
			if animate:
				content.modulate.a = 0.0
				var tween := create_tween()
				tween.tween_property(content, "modulate:a", 1.0, 0.15)
		else:
			content.visible = false

# ============================================================
# PUBLIC API
# ============================================================
func expand() -> void:
	open()

func collapse() -> void:
	close()

func maximize() -> void:
	open()

func show_tab(tab: Tab) -> void:
	_switch_tab(tab)
	if not is_open:
		open()

# ============================================================
# SETTINGS TAB
# ============================================================
func _init_settings_tab() -> void:
	# Notation dropdown
	if notation_option:
		notation_option.clear()
		notation_option.add_item("CDE", 0)
		notation_option.add_item("도레미", 1)
		notation_option.add_item("Both", 2)
		notation_option.item_selected.connect(_on_notation_changed)
	
	# Visual toggles
	if note_label_check:
		note_label_check.toggled.connect(func(v): GameManager.show_note_labels = v)
	if root_check:
		root_check.toggled.connect(func(v): GameManager.highlight_root = v)
	if chord_check:
		chord_check.toggled.connect(func(v): GameManager.highlight_chord = v)
	if scale_check:
		scale_check.toggled.connect(func(v): GameManager.highlight_scale = v)
	
	# Focus Range buttons
	if focus_minus_btn:
		focus_minus_btn.pressed.connect(func(): _adjust_focus_range(-1))
	if focus_plus_btn:
		focus_plus_btn.pressed.connect(func(): _adjust_focus_range(1))
	
	# Deadzone buttons
	if deadzone_minus_btn:
		deadzone_minus_btn.pressed.connect(func(): _adjust_deadzone(-0.5))
	if deadzone_plus_btn:
		deadzone_plus_btn.pressed.connect(func(): _adjust_deadzone(0.5))
	
	# Sync initial values
	_sync_settings_from_game_manager()

func _sync_settings_from_game_manager() -> void:
	if notation_option:
		notation_option.selected = GameManager.current_notation
	if note_label_check:
		note_label_check.button_pressed = GameManager.show_note_labels
	if root_check:
		root_check.button_pressed = GameManager.highlight_root
	if chord_check:
		chord_check.button_pressed = GameManager.highlight_chord
	if scale_check:
		scale_check.button_pressed = GameManager.highlight_scale
	if focus_value_label:
		focus_value_label.text = str(GameManager.focus_range)
	if deadzone_value_label:
		deadzone_value_label.text = str(GameManager.camera_deadzone)

func _on_notation_changed(index: int) -> void:
	GameManager.current_notation = index as MusicTheory.NotationMode
	GameManager.save_settings()

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

# ============================================================
# LIBRARY TAB
# ============================================================
func _init_library_tab() -> void:
	if presets_tab_btn:
		presets_tab_btn.toggled.connect(_on_library_mode_toggled.bind(LibraryTabMode.PRESETS))
	if songs_tab_btn:
		songs_tab_btn.toggled.connect(_on_library_mode_toggled.bind(LibraryTabMode.SONGS))
	if library_save_btn:
		library_save_btn.pressed.connect(_on_library_save_pressed)
		
	_refresh_library_list()

func _on_library_mode_toggled(toggled: bool, mode: LibraryTabMode) -> void:
	if toggled and current_library_mode != mode:
		current_library_mode = mode
		# Update button visuals (optional if toggle group handles it, but explicit is safer)
		if mode == LibraryTabMode.PRESETS and songs_tab_btn: songs_tab_btn.set_pressed_no_signal(false)
		if mode == LibraryTabMode.SONGS and presets_tab_btn: presets_tab_btn.set_pressed_no_signal(false)
		
		selected_library_item = ""
		_refresh_library_list()

func _refresh_library_list() -> void:
	if not preset_list_container: return
	
	# Clear
	for child in preset_list_container.get_children():
		child.queue_free()
		
	var list = []
	if current_library_mode == LibraryTabMode.PRESETS:
		list = ProgressionManager.get_preset_list()
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			list = song_manager.get_song_list()
			
	# Populate
	for i in range(list.size()):
		var data = list[i]
		var item = preset_item_scene.instantiate()
		preset_list_container.add_child(item)
		
		var display_data = data.duplicate()
		if current_library_mode == LibraryTabMode.SONGS:
			display_data["name"] = data.get("title", "Untitled")
			
		item.setup(display_data, i)
		item.load_requested.connect(_on_library_load_requested)
		item.delete_requested.connect(_on_library_delete_requested)
		
		# Connect selection
		if item.has_signal("item_clicked"):
			item.item_clicked.connect(_on_library_item_clicked)
			
		if current_library_mode == LibraryTabMode.PRESETS:
			if item.has_signal("set_default_requested"):
				item.set_default_requested.connect(_on_library_set_default)
			if item.has_signal("reorder_requested"):
				item.reorder_requested.connect(_on_library_reorder)
				
			if item.has_method("set_is_default"):
				var is_def = (display_data.name == GameManager.default_preset_name)
				item.set_is_default(is_def)
		else:
			if item.has_method("set_reorder_visible"):
				item.set_reorder_visible(false)
				
	if not selected_library_item.is_empty():
		_update_library_selection()

func _on_library_save_pressed() -> void:
	var input_name = library_name_input.text.strip_edges()
	var target_name = ""
	
	if not input_name.is_empty():
		target_name = input_name
	elif not selected_library_item.is_empty():
		target_name = selected_library_item
	else:
		return
		
	if current_library_mode == LibraryTabMode.PRESETS:
		ProgressionManager.save_preset(target_name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.save_song(target_name)
			
	library_name_input.text = ""
	selected_library_item = ""
	_refresh_library_list()

func _on_library_load_requested(name: String) -> void:
	if current_library_mode == LibraryTabMode.PRESETS:
		ProgressionManager.load_preset(name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.load_song(name)
			
	selected_library_item = ""
	_update_library_selection()
	# Loading closes the sheet or keeps it open? Maybe minimize?
	# collapse() 

func _on_library_delete_requested(name: String) -> void:
	if current_library_mode == LibraryTabMode.PRESETS:
		ProgressionManager.delete_preset(name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.delete_song(name)
	
	if selected_library_item == name:
		selected_library_item = ""
	_refresh_library_list()

func _on_library_item_clicked(name: String) -> void:
	if selected_library_item == name:
		selected_library_item = ""
	else:
		selected_library_item = name
		if library_name_input:
			library_name_input.text = name
	_update_library_selection()

func _update_library_selection() -> void:
	for child in preset_list_container.get_children():
		if child.has_method("set_selected"):
			var is_target = (child.preset_name == selected_library_item)
			child.set_selected(is_target)

func _on_library_set_default(name: String, is_default: bool) -> void:
	if is_default:
		GameManager.default_preset_name = name
	else:
		if GameManager.default_preset_name == name:
			GameManager.default_preset_name = ""
	GameManager.save_settings()
	_refresh_library_list()

func _on_library_reorder(from_idx: int, to_idx: int) -> void:
	if current_library_mode == LibraryTabMode.PRESETS:
		ProgressionManager.reorder_presets(from_idx, to_idx)
		_refresh_library_list()

# ============================================================
# EAR TRAINER TAB
# ============================================================
func _init_ear_trainer_tab() -> void:
	# Connect Signals
	if et_asc_mode:
		et_asc_mode.toggled.connect(_on_et_mode_toggled.bind(QuizManager.IntervalMode.ASCENDING))
	if et_desc_mode:
		et_desc_mode.toggled.connect(_on_et_mode_toggled.bind(QuizManager.IntervalMode.DESCENDING))
	if et_harm_mode:
		et_harm_mode.toggled.connect(_on_et_mode_toggled.bind(QuizManager.IntervalMode.HARMONIC))
	if et_easy_mode:
		et_easy_mode.toggled.connect(func(v): GameManager.show_target_visual = v)
	
	if et_replay_btn:
		et_replay_btn.pressed.connect(QuizManager.play_current_interval)
	if et_next_btn:
		et_next_btn.pressed.connect(QuizManager.start_interval_quiz)
		
	QuizManager.quiz_started.connect(_on_et_quiz_started)
	QuizManager.quiz_answered.connect(_on_et_quiz_answered)
	
	_populate_et_grid()
	_sync_et_state()
	
	# [UI Update] Rearrange Controls to Top & Add Exit Button
	call_deferred("_rearrange_et_ui")

func _rearrange_et_ui() -> void:
	# 1. Provide Exit Button
	if et_replay_btn:
		var actions_hbox = et_replay_btn.get_parent()
		if actions_hbox:
			pass
			# [User Request] Removed explicit Exit button.
			# Using Auto-Stop on panel close/switch instead.
			# 2. Move ActionsHBox to TOP (Outside ScrollContainer)
			# Structure: ContentContainer (Control) -> EarTrainerContent (Scroll) -> Margin -> VBox -> ActionsHBox
			# Goal: ContentContainer -> NewVBox -> [ActionsHBox, EarTrainerContent]
			var scroll_container = ear_trainer_content
			if not scroll_container: return
			
			var content_container = scroll_container.get_parent()
			if not content_container: return
			
			# Create Wrapper VBox
			var wrapper = VBoxContainer.new()
			wrapper.set_anchors_preset(Control.PRESET_FULL_RECT) # Fill Space
			wrapper.name = "EarTrainerWrapper"
			wrapper.visible = scroll_container.visible # Sync visibility
			
			# Swap in ContentContainer
			content_container.add_child(wrapper)
			content_container.move_child(wrapper, scroll_container.get_index())
			
			# Move ScrollContainer into Wrapper
			scroll_container.reparent(wrapper)
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL # Take remaining space
			scroll_container.visible = true # [Fix] Ensure it's visible inside the wrapper
			
			# Move ActionsHBox into Wrapper (At Top)
			# First, ensure it has a margin/padding?
			var actions_margin = MarginContainer.new()
			actions_margin.add_theme_constant_override("margin_top", 8)
			actions_margin.add_theme_constant_override("margin_left", 12)
			actions_margin.add_theme_constant_override("margin_right", 12)
			actions_margin.add_theme_constant_override("margin_bottom", 4)
			wrapper.add_child(actions_margin)
			wrapper.move_child(actions_margin, 0)
			
			actions_hbox.reparent(actions_margin)
			
			# Update reference in tab switching if needed?
			# _show_content toggles `ear_trainer_content.visible`.
			# But now `ear_trainer_content` is inside `wrapper`.
			# We need `wrapper` to be the one toggled?
			# Or we just let `ear_trainer_content` be toggled, but `wrapper` is always visible?
			# If `wrapper` is visible but correct `ear_trainer_content` is hidden, buttons remain visible?
			# Yes. We need `wrapper` to replace `ear_trainer_content` in the `_show_content` logic.
			# So we must update the `ear_trainer_content` reference to point to `wrapper`.
			ear_trainer_content = wrapper
			# Wait, `ear_trainer_content` is `@onready var`. Changing it works for GDScript logic.
			# But `_show_content` uses `[settings_content, library_content, ear_trainer_content]`.
			# We need to make sure `wrapper` is what gets hidden/shown.
			# Yes, assigning `ear_trainer_content = wrapper` will make `_show_content` use wrapper.

func _populate_et_grid() -> void:
	if not et_interval_grid: return
	
	# Interval Grid Only for now (Migration)
	for child in et_interval_grid.get_children():
		child.queue_free()
	et_checkboxes.clear()
	
	var data = IntervalQuizData.INTERVALS
	var sorted_semitones = data.keys()
	sorted_semitones.sort()
	
	for semitones in sorted_semitones:
		var info = data[semitones]
		var row = ET_ROW_SCENE.instantiate()
		et_interval_grid.add_child(row)
		
		var is_checked = semitones in QuizManager.active_intervals
		var text = "%s (%s)" % [info.name, info.short]
		
		row.setup(text, is_checked, true) # [New] Show Manage Button
		row.checkbox.tooltip_text = "Example: %s" % info.examples[0].get("title", "")
		

		# row.toggled -> _on_et_interval_toggled
		row.toggled.connect(func(on): _on_et_interval_toggled(on, semitones))
		
		# [New] row.manage_requested -> Show Manager Dialog
		if row.has_signal("manage_requested"):
			row.manage_requested.connect(func(): _show_example_manager_dialog(semitones))
		
		et_checkboxes[semitones] = row.checkbox

# var example_manager_dialog: ConfirmationDialog
var example_list_box: VBoxContainer
var pending_manage_interval: int = -1

# var import_dialog: ConfirmationDialog
var import_option_button: OptionButton
var pending_delete_song: String = ""

var _main_theme: Theme = preload("res://ui/resources/main_theme.tres")

# --- Example Manager (Custom Overlay) ---
var example_manager_root: Control
# var example_manager_dialog: ConfirmationDialog
# var example_list_box: VBoxContainer <- Duplicate removed

func _show_example_manager_dialog(semitones: int) -> void:
	pending_manage_interval = semitones
	
	if not example_manager_root:
		_create_example_manager_ui()
		
	# Refresh and Show
	_refresh_example_list()
	example_manager_root.visible = true
	
func _create_example_manager_ui() -> void:
	# 1. Root Overlay (Dim)
	example_manager_root = Control.new()
	example_manager_root.name = "ManageOverlay"
	example_manager_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add to MainUI to cover entire screen
	get_parent().add_child(example_manager_root)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Close on background click
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			example_manager_root.visible = false
	)
	example_manager_root.add_child(dim)
	
	# 2. Main Panel (Centered via CenterContainer)
	var center_cont = CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Pass clicks through to dim? No, CenterCont takes full space.
	# We need mouse_filter to ignore on the container itself so dim gets clicks?
	# CenterContainer defaults to MOUSE_FILTER_STOP? No, MOUSE_FILTER_PASS?
	# Usually better to put CenterContainer ON TOP of Dim, as a sibling.
	# But Dim is already child.
	center_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let click pass to Dim if missed panel?
	# Actually, if we click outside panel, we hit CenterContainer.
	# If CenterContainer ignores mouse, it passes to Dim.
	example_manager_root.add_child(center_cont)
	
	var panel = PanelContainer.new()
	panel.theme = _main_theme # Use Main Theme (Glass Style)
	panel.custom_minimum_size = Vector2(400, 300)
	# panel.set_anchors_preset(Control.PRESET_CENTER) # No need, CenterCont handles it
	center_cont.add_child(panel)
	
	# 3. Content
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	# Title
	var title_hbox = HBoxContainer.new()
	vbox.add_child(title_hbox)
	
	var title = Label.new()
	title.text = "Manage Examples"
	title.theme_type_variation = "HeaderMedium"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "✖"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): example_manager_root.visible = false)
	title_hbox.add_child(close_btn)
	
	# List Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(scroll)
	
	example_list_box = VBoxContainer.new()
	example_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(example_list_box)

	# Footer (Import)
	var import_btn = Button.new()
	import_btn.text = "+ Import from Song Library"
	import_btn.custom_minimum_size = Vector2(0, 40)
	import_btn.pressed.connect(_show_song_import_dialog)
	vbox.add_child(import_btn)

func _refresh_example_list() -> void:
	if not example_list_box: return
	
	# Clear
	for child in example_list_box.get_children():
		child.queue_free()
		
	var riff_manager = _get_riff_manager()
	if not riff_manager: return
	
	var riffs = riff_manager.get_riffs_for_interval(pending_manage_interval)
	
	if riffs.is_empty():
		var label = Label.new()
		label.text = "No examples yet.\nImport a song to start!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.7, 0.7, 0.7)
		example_list_box.add_child(label)
		return
		
	for i in range(riffs.size()):
		var riff = riffs[i]
		var title = riff.get("title", "Untitled")
		var source = riff.get("source", "unknown")
		
		var hbox = HBoxContainer.new()
		example_list_box.add_child(hbox)
		
		var play_btn = Button.new()
		play_btn.text = "▶"
		play_btn.flat = true
		play_btn.tooltip_text = "Preview"
		play_btn.pressed.connect(func(): _preview_riff(riff))
		hbox.add_child(play_btn)
		
		var label = Label.new()
		label.text = title
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		
		# Delete Button (Only for User Imports)
		if source == "user_import" or source == "user":
			var del_btn = Button.new()
			del_btn.text = "🗑" # Trash
			del_btn.flat = true
			del_btn.modulate = Color(1, 0.5, 0.5)
			del_btn.tooltip_text = "Delete"
			del_btn.pressed.connect(func(): _delete_example_riff(i))
			hbox.add_child(del_btn)

func _preview_riff(riff: Dictionary) -> void:
	# Use new public wrapper
	QuizManager.play_riff_preview(riff)

func _delete_example_riff(index: int) -> void:
	var riff_manager = _get_riff_manager()
	if riff_manager:
		riff_manager.delete_riff(pending_manage_interval, index, "interval")
		_refresh_example_list()

# --- Song Import ---
# --- Song Import (Custom Overlay) ---
var import_overlay: Control

func _show_song_import_dialog() -> void:
	if not import_overlay:
		_create_import_ui()
		
	# Populate
	import_option_button.clear()
	var song_manager = GameManager.get_node_or_null("SongManager")
	var has_songs = false
	if song_manager:
		var songs = song_manager.get_song_list()
		if not songs.is_empty():
			has_songs = true
			import_btn_ref.disabled = false
			for s in songs:
				import_option_button.add_item(s.get("title", "Untitled"))
	
	if not has_songs:
		import_option_button.add_item("No songs in library")
		import_option_button.disabled = true
		import_btn_ref.disabled = true
				
	import_overlay.visible = true
	# We don't need to hide manage dialog because we layer on top.

func _create_import_ui() -> void:
	import_overlay = Control.new()
	import_overlay.name = "ImportOverlay"
	import_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add to MainUI to cover entire screen
	get_parent().add_child(import_overlay)
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			import_overlay.visible = false
	)
	import_overlay.add_child(dim)
	
	var center_cont = CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	import_overlay.add_child(center_cont)
	
	var panel = PanelContainer.new()
	panel.theme = _main_theme
	panel.custom_minimum_size = Vector2(350, 200)
	center_cont.add_child(panel)
	
	var margin = MarginContainer.new() # Add margin matching style
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "Import Song"
	title.theme_type_variation = "HeaderMedium"
	vbox.add_child(title)
	
	var label = Label.new()
	label.text = "Select a song from your library:"
	vbox.add_child(label)
	
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

var import_btn_ref: Button

func _on_import_confirmed() -> void:
	if pending_manage_interval == -1: return
	if import_option_button.selected == -1: return
	
	var song_title = import_option_button.get_item_text(import_option_button.selected)
	
	import_overlay.visible = false # Close Import
	# Manage dialog remains visible under it.
	
	var riff_manager = _get_riff_manager()
	if riff_manager:
		var success = riff_manager.import_song_as_riff(pending_manage_interval, song_title)
		if success:
			_refresh_example_list() # Update Manage List
			pending_delete_song = song_title
			_show_delete_prompt(song_title)

func _on_import_canceled() -> void:
	if import_overlay:
		import_overlay.visible = false


# Helper
func _get_riff_manager() -> Node:
	var rm = get_tree().root.find_child("RiffManager", true, false)
	if not rm and GameManager.has_node("RiffManager"):
		rm = GameManager.get_node("RiffManager")
	return rm

var delete_overlay: Control
var delete_label_ref: Label


func _show_delete_prompt(song_title: String) -> void:
	if not delete_overlay:
		_create_delete_ui()
		
	delete_label_ref.text = "Import successful!\n\nDo you want to delete '%s' from the Song Library\nto keep it clean? (A copy is saved in Ear Trainer)" % song_title
	delete_overlay.visible = true

func _create_delete_ui() -> void:
	delete_overlay = Control.new()
	delete_overlay.name = "DeleteOverlay"
	delete_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_parent().add_child(delete_overlay)
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_overlay.add_child(dim)
	
	var center_cont = CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delete_overlay.add_child(center_cont)
	
	var panel = PanelContainer.new()
	panel.theme = _main_theme
	panel.custom_minimum_size = Vector2(350, 180)
	center_cont.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "Clean Up Library"
	title.theme_type_variation = "HeaderMedium"
	vbox.add_child(title)
	
	delete_label_ref = Label.new()
	delete_label_ref.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(delete_label_ref)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)
	
	var keep_btn = Button.new()
	keep_btn.text = "Keep Original"
	keep_btn.flat = true
	keep_btn.pressed.connect(func(): delete_overlay.visible = false)
	hbox.add_child(keep_btn)
	
	var del_btn = Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(func():
		_on_delete_confirmed()
		delete_overlay.visible = false
	)
	hbox.add_child(del_btn)

func _on_delete_confirmed() -> void:
	if pending_delete_song.is_empty(): return
	
	var song_manager = GameManager.get_node_or_null("SongManager")
	if song_manager:
		song_manager.delete_song(pending_delete_song)
		print("Deleted original song: ", pending_delete_song)
		
	if current_library_mode == LibraryTabMode.SONGS and library_content.visible:
		_refresh_library_list()
	
	pending_delete_song = ""

func _open_riff_editor(semitones: int) -> void:
	if not riff_editor_scene: return
	
	var editor = riff_editor_scene.instantiate()
	# MainUI(CanvasLayer)에 추가하여 화면 전체 덮기
	# SidePanel의 부모가 MainUI라고 가정 (씬 구조상 확인됨)
	get_parent().add_child(editor)
	
	if editor.has_method("setup"):
		editor.setup(semitones, "interval")
		
	# 닫힐 때 자동 제거는 editor 내부에서 queue_free() 호출함 (riff_editor.gd:104)
	# 별도 처리 불필요.


func _on_et_interval_toggled(on: bool, semitones: int) -> void:
	if on:
		if not semitones in QuizManager.active_intervals:
			QuizManager.active_intervals.append(semitones)
	else:
		QuizManager.active_intervals.erase(semitones)

func _on_et_mode_toggled(on: bool, mode: int) -> void:
	if on:
		if not mode in QuizManager.active_modes:
			QuizManager.active_modes.append(mode)
	else:
		QuizManager.active_modes.erase(mode)
		if QuizManager.active_modes.is_empty():
			QuizManager.active_modes.append(mode) # Reset
			_sync_et_state() # Revert check

func _sync_et_state() -> void:
	var modes = QuizManager.active_modes
	if et_asc_mode: et_asc_mode.set_pressed_no_signal(QuizManager.IntervalMode.ASCENDING in modes)
	if et_desc_mode: et_desc_mode.set_pressed_no_signal(QuizManager.IntervalMode.DESCENDING in modes)
	if et_harm_mode: et_harm_mode.set_pressed_no_signal(QuizManager.IntervalMode.HARMONIC in modes)
	if et_easy_mode: et_easy_mode.set_pressed_no_signal(GameManager.show_target_visual)

func _on_et_quiz_started(data: Dictionary) -> void:
	if et_feedback_label:
		et_feedback_label.text = "Listen..."
		et_feedback_label.modulate = Color.WHITE

func _on_et_quiz_answered(result: Dictionary) -> void:
	if et_feedback_label:
		if result.correct:
			et_feedback_label.text = "Correct!"
			et_feedback_label.modulate = Color.CYAN
		else:
			et_feedback_label.text = "Try Again"
			et_feedback_label.modulate = Color(1, 0.3, 0.3)
