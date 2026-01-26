# sequence_ui.gd
# 시퀀서 UI 컨트롤러 (슬롯 선택, 재생 버튼, 설정 등)
extends CanvasLayer

# ============================================================
# EXPORTS & CONSTANTS
# ============================================================
var slot_button_scene: PackedScene = preload("res://ui/sequence/slot_button.tscn")

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var slot_container: HBoxContainer = %SlotContainer
@onready var play_button: Button = %PlayButton
@onready var stop_button: Button = %StopButton

# Controls
@onready var bar_count_spin_box: SpinBox = %BarCountSpinBox
@onready var split_check_button: CheckButton = %SplitCheckButton
@onready var bpm_spin_box: SpinBox = %BPMSpinBox

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	# Manager Signals
	ProgressionManager.slot_selected.connect(_highlight_selected)
	ProgressionManager.slot_updated.connect(_update_slot_label)
	ProgressionManager.selection_cleared.connect(_on_selection_cleared)
	ProgressionManager.settings_updated.connect(_on_settings_updated) # New
	
	GameManager.settings_changed.connect(_sync_ui_from_manager) # Update BPM/etc from global settings
	
	# Playback Signals
	play_button.pressed.connect(_toggle_playback)
	if stop_button:
		stop_button.pressed.connect(_on_stop_button_pressed)
	
	EventBus.bar_changed.connect(_highlight_playing)
	EventBus.sequencer_playing_changed.connect(_on_sequencer_playing_changed)
	
	# UI Controls
	bar_count_spin_box.value_changed.connect(_on_bar_count_changed)
	split_check_button.toggled.connect(_on_split_toggled)
	bpm_spin_box.value_changed.connect(_on_bpm_changed)
	
	# Initial Setup
	_sync_ui_from_manager()
	_rebuild_slots()

# ============================================================
# UI LOGIC
# ============================================================

func _sync_ui_from_manager() -> void:
	bar_count_spin_box.set_value_no_signal(ProgressionManager.bar_count)
	split_check_button.set_pressed_no_signal(ProgressionManager.chords_per_bar == 2)
	bpm_spin_box.set_value_no_signal(GameManager.bpm)

func _rebuild_slots() -> void:
	# 1. 기존 슬롯 제거
	for child in slot_container.get_children():
		child.queue_free()
	
	# 2. 새 슬롯 생성
	var total_slots = ProgressionManager.total_slots
	
	for i in range(total_slots):
		var btn = slot_button_scene.instantiate()
		slot_container.add_child(btn)
		
		# 설정 (Duck typing usage)
		if btn.has_method("setup"):
			btn.setup(i)
		
		btn.pressed.connect(_on_slot_clicked.bind(i))
		if btn.has_signal("right_clicked"):
			btn.right_clicked.connect(_on_slot_right_clicked)
		
		# 데이터 로드
		var data = ProgressionManager.get_slot(i)
		if data and btn.has_method("update_info"):
			btn.update_info(data)

func _on_settings_updated(_bar_count: int, _chords_per_bar: int) -> void:
	_sync_ui_from_manager()
	_rebuild_slots()

# ============================================================
# CONTROL CALLBACKS
# ============================================================
func _on_bar_count_changed(value: float) -> void:
	ProgressionManager.update_settings(int(value), ProgressionManager.chords_per_bar)

func _on_split_toggled(toggled: bool) -> void:
	var density = 2 if toggled else 1
	ProgressionManager.update_settings(ProgressionManager.bar_count, density)

func _on_bpm_changed(value: float) -> void:
	GameManager.bpm = int(value)

# ============================================================
# SLOT INTERACTION
# ============================================================
func _on_slot_clicked(index: int) -> void:
	if index >= ProgressionManager.total_slots:
		return
	
	if ProgressionManager.selected_index == index:
		ProgressionManager.selected_index = -1
	else:
		ProgressionManager.selected_index = index

func _on_slot_right_clicked(index: int) -> void:
	ProgressionManager.clear_slot(index)

func _highlight_selected(selected_idx: int) -> void:
	var children = slot_container.get_children()
	for i in range(children.size()):
		var btn = children[i]
		if not btn.has_method("set_highlight"): continue
		
		if i == selected_idx:
			btn.set_highlight("selected")
		else:
			btn.set_highlight("none")

func _update_slot_label(index: int, data: Dictionary) -> void:
	if index >= slot_container.get_child_count():
		return
	
	var btn = slot_container.get_child(index)
	if btn and btn.has_method("update_info"):
		btn.update_info(data)

# ============================================================
# PLAYBACK VISUALS
# ============================================================
func _highlight_playing(playing_step: int) -> void:
	var children = slot_container.get_children()
	for i in range(children.size()):
		var btn = children[i]
		if not btn.has_method("set_highlight"): continue
		
		if i == playing_step:
			btn.set_highlight("playing")
		elif i == ProgressionManager.selected_index:
			btn.set_highlight("selected")
		else:
			btn.set_highlight("none")

func _on_sequencer_playing_changed(is_playing: bool) -> void:
	play_button.text = "PAUSE" if is_playing else "PLAY"

# ============================================================
# INPUT & SIGNALS
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			_toggle_playback()
			get_viewport().set_input_as_handled()

func _toggle_playback() -> void:
	EventBus.request_toggle_playback.emit()

func _on_stop_button_pressed() -> void:
	EventBus.request_stop_playback.emit()
	_highlight_playing(-1)

func _on_selection_cleared():
	_highlight_selected(-1)
