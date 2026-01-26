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
# @onready var split_check_button: CheckButton = %SplitCheckButton
@onready var split_bar_button: Button = %SplitBarButton # [New]
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
	ProgressionManager.loop_range_changed.connect(_on_loop_range_changed)
	
	GameManager.settings_changed.connect(_sync_ui_from_manager) # Update BPM/etc from global settings
	
	# Playback Signals
	play_button.pressed.connect(_toggle_playback)
	play_button.focus_mode = Control.FOCUS_NONE
	
	if stop_button:
		stop_button.pressed.connect(_on_stop_button_pressed)
		stop_button.focus_mode = Control.FOCUS_NONE
	
	EventBus.bar_changed.connect(_highlight_playing)
	EventBus.sequencer_playing_changed.connect(_on_sequencer_playing_changed)
	
	# UI Controls
	bar_count_spin_box.value_changed.connect(_on_bar_count_changed)
	# split_check_button.toggled.connect(_on_split_toggled)
	if split_bar_button:
		split_bar_button.pressed.connect(_on_split_bar_pressed)
		split_bar_button.focus_mode = Control.FOCUS_NONE
		
	bpm_spin_box.value_changed.connect(_on_bpm_changed)
	
	# [New] Step/Beat Update Listener
	EventBus.sequencer_step_beat_changed.connect(_on_step_beat_changed)
	
	# Initial Setup
	_sync_ui_from_manager()
	_rebuild_slots()

# ============================================================
# UI LOGIC
# ============================================================

func _sync_ui_from_manager() -> void:
	bar_count_spin_box.set_value_no_signal(ProgressionManager.bar_count)
	# split_check_button.set_pressed_no_signal(ProgressionManager.chords_per_bar == 2)
	bpm_spin_box.set_value_no_signal(GameManager.bpm)
	
	_update_split_button_state()

func _rebuild_slots() -> void:
	# 1. 기존 슬롯 제거
	for child in slot_container.get_children():
		child.queue_free()
	
	# 2. 새 슬롯 생성
	var total_slots = ProgressionManager.total_slots
	
	for i in range(total_slots):
		var btn = slot_button_scene.instantiate()
		btn.focus_mode = Control.FOCUS_NONE # [New] Prevent Focus Stealing
		slot_container.add_child(btn)
		
		# [Updated] Beats count fetch
		var beats = ProgressionManager.get_beats_for_slot(i)
		
		# [New] Dynamic Sizing
		# Full Slot (4 beats) = 140px
		# Split Slot (2 beats) = 65px
		var width = 140.0 if beats >= 4 else 65.0
		btn.custom_minimum_size = Vector2(width, 80)
		
		# 설정 (Duck typing usage)
		if btn.has_method("setup"):
			btn.setup(i, beats)
			
		# [New] Beat Click Connect
		if btn.has_signal("beat_clicked"):
			btn.beat_clicked.connect(_on_slot_beat_clicked)
		
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
	ProgressionManager.update_settings(int(value))

# func _on_split_toggled(toggled: bool) -> void: ... (Removed)

func _on_split_bar_pressed() -> void:
	var idx = ProgressionManager.selected_index
	if idx < 0: return
	
	var bar_idx = ProgressionManager.get_bar_index_for_slot(idx)
	if bar_idx >= 0:
		ProgressionManager.toggle_bar_split(bar_idx)
		
		# 리빌드 후 선택 복원 시도? (인덱스가 바뀌므로 복잡, 일단 해제)
		# ProgressionManager에서 이미 리셋됨

func _on_bpm_changed(value: float) -> void:
	GameManager.bpm = int(value)

# ============================================================
# SLOT INTERACTION
# ============================================================
func _on_slot_clicked(index: int) -> void:
	if index >= ProgressionManager.total_slots:
		return
	
	if Input.is_key_pressed(KEY_SHIFT):
		# [New] Shift+Click: Loop Selection
		if ProgressionManager.selected_index != -1:
			# 기존 선택이 있으면 거기서부터 현재까지 범위 지정
			var start = min(ProgressionManager.selected_index, index)
			var end = max(ProgressionManager.selected_index, index)
			ProgressionManager.set_loop_range(start, end)
		else:
			# 선택된 게 없으면 그냥 단일 선택 처리와 동일하게 가거나, 자기 자신만 루프 걸 수도 있음
			# 여기서는 그냥 일반 선택으로 fallback
			ProgressionManager.selected_index = index
			ProgressionManager.clear_loop_range()
	else:
		# Normal Click: Clear Loop & Toggle Select
		ProgressionManager.clear_loop_range()
		
		if ProgressionManager.selected_index == index:
			ProgressionManager.selected_index = -1
		else:
			ProgressionManager.selected_index = index
	
	_update_split_button_state()

func _on_slot_beat_clicked(slot_idx: int, beat_idx: int) -> void:
	# [New] Seek Playhead
	%Sequencer.seek(slot_idx, beat_idx)

func _on_slot_right_clicked(index: int) -> void:
	ProgressionManager.clear_slot(index)

func _on_loop_range_changed(_start: int, _end: int) -> void:
	# 루프 범위가 바뀌면 하이라이트 갱신
	_highlight_selected(ProgressionManager.selected_index)

func _highlight_selected(selected_idx: int) -> void:
	var children = slot_container.get_children()
	for i in range(children.size()):
		var btn = children[i]
		if not btn.has_method("set_highlight"): continue
		
		# 1. 루프 범위 확인
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index
		var is_in_loop = false
		if loop_start != -1 and loop_end != -1:
			if i >= loop_start and i <= loop_end:
				is_in_loop = true
		
		if i == selected_idx:
			btn.set_highlight("selected")
		elif is_in_loop:
			btn.set_highlight("selected") # 루프 구간도 선택된 것처럼 표시 (혹은 별도 스타일)
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
		
		# 1. 루프 범위 확인
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index
		var is_in_loop = false
		if loop_start != -1 and loop_end != -1:
			if i >= loop_start and i <= loop_end:
				is_in_loop = true

		if i == playing_step:
			btn.set_highlight("playing")
		elif i == ProgressionManager.selected_index:
			btn.set_highlight("selected")
		elif is_in_loop:
			btn.set_highlight("selected") # 루프 구간 표시
		else:
			btn.set_highlight("none")
			
func _on_step_beat_changed(step: int, beat: int) -> void:
	# 각 슬롯 버튼에게 Playhead 업데이트 요청
	var children = slot_container.get_children()
	for i in range(children.size()):
		var btn = children[i]
		if not btn.has_method("update_playhead"): continue
		
		if i == step:
			btn.update_playhead(beat)
		else:
			btn.update_playhead(-1) # inactive

func _update_split_button_state() -> void:
	if not split_bar_button: return
	
	var idx = ProgressionManager.selected_index
	if idx < 0:
		split_bar_button.disabled = true
		split_bar_button.text = "Split/Merge Bar"
		return
		
	split_bar_button.disabled = false
	var bar_idx = ProgressionManager.get_bar_index_for_slot(idx)
	var density = ProgressionManager.bar_densities[bar_idx]
	split_bar_button.text = "Merge Bar" if density == 2 else "Split Bar"

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
	_update_split_button_state()
