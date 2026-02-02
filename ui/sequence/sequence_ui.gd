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
@onready var slot_container: Container = %SlotContainer
@onready var loop_overlay_panel: Panel = %LoopOverlayPanel

# Controls
@onready var bar_count_spin_box: SpinBox = %BarCountSpinBox
# @onready var split_check_button: CheckButton = %SplitCheckButton
@onready var split_bar_button: Button = %SplitBarButton # [New]

@onready var library_button: Button = %LibraryButton
@onready var library_panel: Control = %LibraryPanel

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	# Manager Signals
	ProgressionManager.slot_selected.connect(_highlight_selected)
	ProgressionManager.slot_updated.connect(_update_slot_label)
	ProgressionManager.selection_cleared.connect(_on_selection_cleared)
	ProgressionManager.settings_updated.connect(_on_settings_updated)
	ProgressionManager.loop_range_changed.connect(_on_loop_range_changed)

	GameManager.settings_changed.connect(_sync_ui_from_manager)
		
	var clear_melody_button = %ClearMelodyButton
	if clear_melody_button:
		clear_melody_button.pressed.connect(_clear_melody)
		clear_melody_button.focus_mode = Control.FOCUS_NONE
		
	var quantize_button = %QuantizeButton
	if quantize_button:
		quantize_button.pressed.connect(_on_quantize_pressed)
		quantize_button.focus_mode = Control.FOCUS_NONE

	# MelodyManager Signals (Global) handled by HUD now for UI

	# Library
	if library_button:
		library_button.pressed.connect(_toggle_library_panel)
		library_button.focus_mode = Control.FOCUS_NONE

	if library_panel:
		library_panel.close_requested.connect(_toggle_library_panel)

	EventBus.bar_changed.connect(_highlight_playing)

	# UI Controls
	bar_count_spin_box.value_changed.connect(_on_bar_count_changed)
	# SpinBox 텍스트 입력 비활성화 (화살표 클릭 시 포커스 방지)
	var line_edit = bar_count_spin_box.get_line_edit()
	if line_edit:
		line_edit.focus_mode = Control.FOCUS_NONE
		line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE # 클릭해서 입력하는 것도 막으려면 IGNORE, 아니면 FOCUS_NONE만
	# split_check_button.toggled.connect(_on_split_toggled)
	if split_bar_button:
		split_bar_button.pressed.connect(_on_split_bar_pressed)
		split_bar_button.focus_mode = Control.FOCUS_NONE
	
	# [New] Step/Beat Update Listener
	if not EventBus.sequencer_step_beat_changed.is_connected(_on_step_beat_changed):
		EventBus.sequencer_step_beat_changed.connect(_on_step_beat_changed)
	
	# [New] Close Library Request
	EventBus.request_close_library.connect(_close_library_panel)
	
	# Initial Setup
	_setup_loop_overlay_style()
	_sync_ui_from_manager()
	_rebuild_slots()

func _toggle_library_panel() -> void:
	if not library_panel: return
	
	library_panel.visible = !library_panel.visible
	
	if library_panel.visible:
		# 라이브러리 열리면 세팅창 닫기
		EventBus.request_close_settings.emit()
		
		if library_panel.has_method("refresh_list"):
			library_panel.refresh_list()

func _close_library_panel() -> void:
	if library_panel and library_panel.visible:
		library_panel.visible = false

func _setup_loop_overlay_style() -> void:
	if not loop_overlay_panel: return
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.9, 0.4, 0.15) # 은은한 노란 배경
	style.border_color = Color(1.0, 0.8, 0.2, 0.8) # 진한 노란 테두리
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	loop_overlay_panel.add_theme_stylebox_override("panel", style)

# ============================================================
# UI LOGIC
# ============================================================

func _sync_ui_from_manager() -> void:
	bar_count_spin_box.set_value_no_signal(ProgressionManager.bar_count)
	# split_check_button.set_pressed_no_signal(ProgressionManager.chords_per_bar == 2)
	
	_update_split_button_state()
	
	# [New] Dynamic Grid Logic
	var total_bars = ProgressionManager.bar_count
	
	# 4마디 초과시 높이 확장 (2줄)
	# 1줄 높이: 90px, 2줄: 175px
	var scroll_container = %SequencerScroll
	if scroll_container:
		if total_bars > 4:
			scroll_container.custom_minimum_size.y = 175
		else:
			scroll_container.custom_minimum_size.y = 90

func _rebuild_slots() -> void:
	# 1. 기존 슬롯 제거
	for child in slot_container.get_children():
		child.queue_free()
	
	# 2. 새 슬롯 생성 (Row Based)
	var total_bars = ProgressionManager.bar_count
	var slot_global_index = 0
	
	var current_row: HBoxContainer = null
	
	for bar_i in range(total_bars):
		# 4마디마다 새로운 줄(Row) 생성
		if bar_i % 4 == 0:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 5)
			current_row.alignment = BoxContainer.ALIGNMENT_CENTER
			slot_container.add_child(current_row)
		
		# 현재 마디의 슬롯 개수 확인
		var density = ProgressionManager.bar_densities[bar_i]
		
		# 해당 마디의 슬롯들 생성
		for i in range(density):
			var slot_idx = slot_global_index
			slot_global_index += 1
			
			var btn = slot_button_scene.instantiate()
			btn.focus_mode = Control.FOCUS_NONE
			current_row.add_child(btn)
			
			# Beats logic
			var beats = 4 if density == 1 else 2
			
			# Dynamic Sizing
			var width = 140.0 if beats >= 4 else 65.0
			btn.custom_minimum_size = Vector2(width, 80)
			
			# Setup
			if btn.has_method("setup"):
				btn.setup(slot_idx, beats)
				
			# Signals
			if btn.has_signal("beat_clicked"):
				btn.beat_clicked.connect(_on_slot_beat_clicked)
			btn.pressed.connect(_on_slot_clicked.bind(slot_idx))
			if btn.has_signal("right_clicked"):
				btn.right_clicked.connect(_on_slot_right_clicked)
			
			# Data Load
			var data = ProgressionManager.get_slot(slot_idx)
			if data and btn.has_method("update_info"):
				btn.update_info(data)
	
	call_deferred("_update_loop_overlay")

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

# func _on_bpm_changed(value: float) -> void: ... (Removed)

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
		# Normal Click
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index
		var is_loop_active = (loop_start != -1 and loop_end != -1)
		
		if is_loop_active:
			# [Refinement] 루프가 활성화된 상태라면, 클릭 시 루프만 해제하고 슬롯 선택은 하지 않음
			ProgressionManager.clear_loop_range()
		else:
			# 루프가 없는 상태라면 정상적으로 슬롯 선택/해제 토글
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
	_update_loop_overlay()

func _update_loop_overlay() -> void:
	if not loop_overlay_panel: return
	
	# [Fix] Layout update requires waiting for the frame to finish, 
	# especially after rebuilding slots.
	await get_tree().process_frame
	
	var start = ProgressionManager.loop_start_index
	var end = ProgressionManager.loop_end_index
	
	if start == -1 or end == -1 or start >= slot_container.get_child_count() or end >= slot_container.get_child_count():
		loop_overlay_panel.visible = false
		return
		
	var start_node = slot_container.get_child(start)
	var end_node = slot_container.get_child(end)
	
	if not (start_node is Control) or not (end_node is Control):
		loop_overlay_panel.visible = false
		return
		
	loop_overlay_panel.visible = true
	
	# Global Position Calculation (Global Rect)
	var start_rect = start_node.get_global_rect()
	var end_rect = end_node.get_global_rect()
	
	# Merge Rects
	var full_rect = start_rect.merge(end_rect)
	
	# Expand slightly for visual padding
	var padding = 6.0
	full_rect = full_rect.grow(padding)
	
	# Apply to Panel (Convert global rect back to local position if needed, or just set global)
	# Since Panel is child of SequenceUI (CanvasLayer), its position is relative to viewport if anchors are top-left?
	# Wait, our Panel has anchors centered. Let's just set global_position/size.
	
	loop_overlay_panel.global_position = full_rect.position
	loop_overlay_panel.custom_minimum_size = full_rect.size
	loop_overlay_panel.size = full_rect.size

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
			btn.set_highlight("loop") # [Fixed] 루프 구간은 별도 스타일(White) 적용
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
	var buttons = _get_all_slot_buttons()
	for i in range(buttons.size()):
		var btn = buttons[i]
		if btn.has_method("set_highlight"):
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
				btn.set_highlight("loop")
			else:
				btn.set_highlight("none")
			
			# [New] Auto-scroll to playing row
			if i == playing_step and btn.is_inside_tree():
				_ensure_visible(btn)

# [New] Helper to traverse nested rows
func _get_all_slot_buttons() -> Array:
	var buttons = []
	for row in slot_container.get_children():
		if row is HBoxContainer:
			for btn in row.get_children():
				buttons.append(btn)
	return buttons
	
func _ensure_visible(control: Control) -> void:
	# Basic visibility check logic
	# Since scrolling is manual or locked, we might want to auto scroll vertically if we had vertical scroll enabled.
	# But actually vertical scroll is disabled now? No, we re-enabled vertical but disabled horizontal?
	# Wait, user earlier said "Scroll appears".
	# If we have 2 rows, it expands.
	# But if it's very long, scroll might be useful.
	pass
			
func _on_step_beat_changed(step: int, beat: int) -> void:
	# Update localized beat indicator on the active slot
	var buttons = _get_all_slot_buttons()
	
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == step:
			if btn.has_method("update_playhead"):
				btn.update_playhead(beat)
		else:
			if btn.has_method("update_playhead"):
				btn.update_playhead(-1) # Hide playhead

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

# ============================================================
# INPUT & SIGNALS
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			# Delegate to EventBus
			EventBus.request_toggle_playback.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			EventBus.request_toggle_recording.emit() # Need to define this signal or handle differently
			# Since we removed the record button toggle logic from here, we should probably emit a request.
			# But for now let's assume HUD handles UI, but key shortcut might need a manager or bus signal.
			# Let's keep existing logic but directly call manager?
			# Actually, we should probably add `request_toggle_recording` to EventBus for consistency.
			# For now, let's just do:
			var mm = GameManager.get_node_or_null("MelodyManager")
			if mm:
				if mm.is_recording: mm.stop_recording()
				else: mm.start_recording()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE:
			# Only if not editing text (simple check: focus mode)
			# But for now let's be safe and require modifiers or explicit focus check
			if Input.is_key_pressed(KEY_SHIFT): # Shift + Delete to clear melody
				_clear_melody()
				get_viewport().set_input_as_handled()
		
		# [New] Quantize (Q)
		elif event.keycode == KEY_Q:
			_on_quantize_pressed()
			get_viewport().set_input_as_handled()
			
		# [New] Undo (Ctrl+Z / Cmd+Z)
		elif event.keycode == KEY_Z:
			if event.ctrl_pressed or event.meta_pressed:
				_undo_melody()
				get_viewport().set_input_as_handled()

# func _toggle_playback() ... Removed
# func _toggle_record_macro() ... Removed
# func _on_stop_button_pressed() ... Removed
# func _on_record_toggled() ... Removed

func _clear_melody() -> void:
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("clear_melody"):
		melody_manager.clear_melody()
		# TODO: Visual feedback via UI toast?

func _undo_melody() -> void:
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("undo_last_note"):
		melody_manager.undo_last_note()

func _on_quantize_pressed() -> void:
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("quantize_notes"):
		melody_manager.quantize_notes()

# func _on_recording_started() ... Removed
# func _on_recording_stopped() ... Removed

func _on_selection_cleared():
	_highlight_selected(-1)
	_update_split_button_state()
