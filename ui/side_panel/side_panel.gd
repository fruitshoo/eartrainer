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
	
	# EventBus 연결
	EventBus.request_toggle_settings.connect(toggle)
	EventBus.request_show_side_panel_tab.connect(_on_request_show_tab)
	EventBus.request_collapse_side_panel.connect(close)
	EventBus.request_close_settings.connect(close)
	
	# Settings 초기화 (기존 코드 유지)
	_init_settings_tab()
	_init_library_tab()
	_init_ear_trainer_tab()

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
		
		row.setup(text, is_checked, true)
		row.checkbox.tooltip_text = "Example: %s" % info.examples[0].get("title", "")
		

		# row.toggled -> _on_et_interval_toggled
		row.toggled.connect(func(on): _on_et_interval_toggled(on, semitones))
		# row.edit_requested -> Open RiffEditor
		if row.has_signal("edit_requested"):
			row.edit_requested.connect(func(): _open_riff_editor(semitones))
		
		et_checkboxes[semitones] = row.checkbox

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
