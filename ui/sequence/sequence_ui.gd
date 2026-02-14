# sequence_ui.gd
# 시퀀서 UI 컨트롤러 (슬롯 선택, 재생 버튼, 설정 등)
extends Control

# ============================================================
# EXPORTS & CONSTANTS
# ============================================================
var slot_button_scene: PackedScene = preload("res://ui/sequence/slot_button.tscn")

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var slot_container: Container = %SlotContainer
@onready var loop_overlay_panel: SequenceLoopOverlay = %LoopOverlayPanel
@onready var context_menu: SequenceContextMenu

# Controls
@onready var bar_count_spin_box: SpinBox = %BarCountSpinBox
@onready var time_sig_button: Button = %TimeSigButton # [New]
@onready var playback_mode_button: OptionButton = %PlaybackModeButton # [New]

# @onready var split_check_button: CheckButton = %SplitCheckButton
@onready var split_bar_button: Button = %SplitBarButton # [New]


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	_setup_signals()
	_setup_controls()
	_setup_context_menu()
	
	_sync_ui_from_manager()
	_rebuild_slots()

func _setup_signals() -> void:
	ProgressionManager.slot_selected.connect(_highlight_selected)
	ProgressionManager.slot_updated.connect(_update_slot_label)
	ProgressionManager.selection_cleared.connect(_on_selection_cleared)
	ProgressionManager.settings_updated.connect(_on_settings_updated)
	ProgressionManager.loop_range_changed.connect(_on_loop_range_changed)

	GameManager.settings_changed.connect(_sync_ui_from_manager)
	
	EventBus.bar_changed.connect(_highlight_playing)
	EventBus.sequencer_step_beat_changed.connect(_on_step_beat_changed)
	EventBus.request_close_library.connect(_close_library_panel)
	
	EventBus.tile_right_clicked.connect(_on_tile_right_clicked)
	EventBus.tile_clicked.connect(_on_tile_clicked)

func _setup_controls() -> void:
	var clear_melody_button = %ClearMelodyButton
	if clear_melody_button:
		clear_melody_button.pressed.connect(_clear_melody)
		clear_melody_button.focus_mode = Control.FOCUS_NONE
		
	var quantize_button = %QuantizeButton
	if quantize_button:
		quantize_button.pressed.connect(_on_quantize_pressed)
		quantize_button.focus_mode = Control.FOCUS_NONE

	bar_count_spin_box.value_changed.connect(_on_bar_count_changed)
	var line_edit = bar_count_spin_box.get_line_edit()
	if line_edit:
		line_edit.focus_mode = Control.FOCUS_NONE
		line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	if split_bar_button:
		split_bar_button.pressed.connect(_on_split_bar_pressed)
		split_bar_button.focus_mode = Control.FOCUS_NONE
		
	if time_sig_button:
		time_sig_button.pressed.connect(_on_time_sig_pressed)
		
	if playback_mode_button:
		playback_mode_button.item_selected.connect(_on_playback_mode_selected)


func _close_library_panel() -> void:
	EventBus.request_collapse_side_panel.emit()

# _setup_loop_overlay_style() removed - logic moved to SequenceLoopOverlay.gd

# ... (rest of controls)
	
func _setup_context_menu() -> void:
	context_menu = SequenceContextMenu.new()
	add_child(context_menu)
	
	context_menu.chord_type_selected.connect(func(type):
		if context_menu.target_slot_index != -1:
			_update_slot_type(context_menu.target_slot_index, type)
	)
	context_menu.delete_requested.connect(func():
		if context_menu.target_slot_index != -1:
			ProgressionManager.clear_slot(context_menu.target_slot_index)
	)
	context_menu.replace_requested.connect(func():
		if context_menu.target_slot_index != -1:
			call_deferred("_open_pie_menu_for_slot", context_menu.target_slot_index)
	)

func _update_slot_type(index: int, new_type: String) -> void:
	var data = ProgressionManager.get_slot(index)
	if data:
		data["type"] = new_type
		ProgressionManager.slot_updated.emit(index, data)
		ProgressionManager.save_session()

# ============================================================
# UI LOGIC
# ============================================================


func _sync_ui_from_manager() -> void:
	bar_count_spin_box.set_value_no_signal(ProgressionManager.bar_count)
	# split_check_button.set_pressed_no_signal(ProgressionManager.chords_per_bar == 2)
	
	_update_split_button_state()
	
	# [New] Time Sig UI
	if time_sig_button:
		var beats = ProgressionManager.beats_per_bar
		time_sig_button.text = "%d/4" % beats
		
	if playback_mode_button:
		playback_mode_button.selected = ProgressionManager.playback_mode

	
	# [New] Dynamic Grid Logic
	var total_bars = ProgressionManager.bar_count
	
	# 4마디 초과시 높이 확장 (2줄) - 트윈 애니메이션
	# 1줄 높이: 90px, 2줄: 175px
	var scroll_container = %SequencerScroll
	if scroll_container:
		var target_height = 175.0 if total_bars > 4 else 90.0
		var current_height = scroll_container.custom_minimum_size.y
		
		# [Fix] Only animate when height actually changes (prevents flash during playback)
		if abs(current_height - target_height) > 1.0:
			# 높이 변경 트윈
			var height_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			height_tween.tween_property(scroll_container, "custom_minimum_size:y", target_height, 0.25)
			
			# 컨텐츠 페이드 인 효과 (슬롯 컨테이너) - 높이 변경 시에만
			if slot_container:
				slot_container.modulate.a = 0.0
				height_tween.parallel().tween_property(slot_container, "modulate:a", 1.0, 0.25)
		# else: height unchanged, do nothing (no fade effect)

func _rebuild_slots() -> void:
	# 1. Gather current buttons for pooling
	var pool = _get_all_slot_buttons()
	for btn in pool:
		btn.get_parent().remove_child(btn)
		
	# 2. Clear rows
	for child in slot_container.get_children():
		child.queue_free()
	
	# 3. Reconstruct
	var total_bars = ProgressionManager.bar_count
	var slot_global_index = 0
	var current_row: HBoxContainer = null
	
	for bar_i in range(total_bars):
		if bar_i % 4 == 0:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 5)
			current_row.alignment = BoxContainer.ALIGNMENT_CENTER
			slot_container.add_child(current_row)
		
		var density = ProgressionManager.bar_densities[bar_i]
		for i in range(density):
			var slot_idx = slot_global_index
			slot_global_index += 1
			
			# Reuse from pool or instantiate
			var btn: Control
			if not pool.is_empty():
				btn = pool.pop_back()
			else:
				btn = slot_button_scene.instantiate()
				btn.focus_mode = Control.FOCUS_NONE
				# Reconnect signals for new nodes only
				_connect_slot_signals(btn)
			
			current_row.add_child(btn)
			
			var beats = ProgressionManager.beats_per_bar if density == 1 else 2
			var width = 140.0 if beats >= 3 else 65.0
			btn.custom_minimum_size = Vector2(width, 80)
			
			if btn.has_method("setup"):
				btn.setup(slot_idx, beats)
				
			var data = ProgressionManager.get_slot(slot_idx)
			if data and btn.has_method("update_info"):
				btn.update_info(data)
	
	# 4. Clean up unused buttons
	for leftover in pool:
		leftover.queue_free()
		
	call_deferred("_update_loop_overlay")

func _connect_slot_signals(btn: Control) -> void:
	if btn.has_signal("beat_clicked"):
		btn.beat_clicked.connect(_on_slot_beat_clicked)
	if btn.has_signal("slot_pressed"):
		btn.slot_pressed.connect(_on_slot_clicked)
	if btn.has_signal("right_clicked"):
		btn.right_clicked.connect(_on_slot_right_clicked)
	
	# [Fix] Restore playing highlight after rebuild to prevent flash on first bar transition
	if EventBus.is_sequencer_playing:
		var sequencer = get_tree().get_first_node_in_group("sequencer")
		if sequencer:
			call_deferred("_highlight_playing", sequencer.current_step)

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
		
		# [Fix] Restore selection to the modified bar's first slot
		# This prevents highlight from jumping or disappearing.
		var new_idx = ProgressionManager.get_slot_index_for_bar(bar_idx)
		if new_idx >= 0:
			ProgressionManager.selected_index = new_idx

func _on_time_sig_pressed() -> void:
	var current = ProgressionManager.beats_per_bar
	var next = 3 if current == 4 else 4
	ProgressionManager.set_time_signature(next)

func _on_playback_mode_selected(index: int) -> void:
	ProgressionManager.playback_mode = index as MusicTheory.ChordPlaybackMode
	ProgressionManager.save_session()


# func _on_bpm_changed(value: float) -> void: ... (Removed)

# ============================================================
# SLOT INTERACTION
# ============================================================
func _on_slot_clicked(index: int) -> void:
	if index >= ProgressionManager.total_slots:
		return
	
	# [New] Cmd+Click / Ctrl+Click: Select Slot for Input (Wait for Tile Click)
	# Use is_key_pressed for immediate check, or check event modifiers if passed (but this is a signal callback)
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		# Force select and clear loop
		ProgressionManager.selected_index = index
		ProgressionManager.clear_loop_range()
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
	# [New] Cmd+Click on Beat also triggers Slot Selection (same as clicking slot)
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		_on_slot_clicked(slot_idx) # Delegate to slot click handler
		return
		
	# [New] Seek Playhead (Normal Click)
	%Sequencer.seek(slot_idx, beat_idx)

func _on_slot_right_clicked(index: int) -> void:
	if context_menu:
		context_menu.show_at_mouse(index)

func _on_loop_range_changed(_start: int, _end: int) -> void:
	# 루프 범위가 바뀌면 하이라이트 갱신
	_highlight_selected(ProgressionManager.selected_index)
	_update_loop_overlay()

func _update_loop_overlay() -> void:
	if not loop_overlay_panel: return
	
	var start = ProgressionManager.loop_start_index
	var end = ProgressionManager.loop_end_index
	var buttons = _get_all_slot_buttons()
	
	loop_overlay_panel.update_overlay(buttons, start, end)


# State tracking for highlight optimization
var _current_playing_step: int = -1

func _highlight_selected(selected_idx: int) -> void:
	_update_all_slots_visual_state()
	
	# ... (Dynamic Scale Override logic remains)
	if selected_idx >= 0:
		var data = ProgressionManager.get_chord_data(selected_idx)
		if not data.is_empty():
			_apply_scale_override_for_slot(data)
		else:
			GameManager.clear_scale_override()
	else:
		GameManager.clear_scale_override()

func _highlight_playing(playing_step: int) -> void:
	_current_playing_step = playing_step
	_update_all_slots_visual_state()

func _update_all_slots_visual_state() -> void:
	var children = _get_all_slot_buttons()
	var loop_start = ProgressionManager.loop_start_index
	var loop_end = ProgressionManager.loop_end_index
	var selected_idx = ProgressionManager.selected_index
	var is_loop_active = (loop_start != -1 and loop_end != -1)
	
	for i in range(children.size()):
		var btn = children[i]
		if not btn.has_method("set_state"): continue
		
		var is_playing = (i == _current_playing_step)
		var is_selected = (i == selected_idx)
		var is_in_loop = false
		if is_loop_active:
			if i >= loop_start and i <= loop_end:
				is_in_loop = true
		
		btn.set_state(is_playing, is_selected, is_in_loop)
		
		# Auto-scroll logic (keep simple)
		if is_playing and btn.is_inside_tree():
			_ensure_visible(btn)

func _update_slot_label(index: int, data: Dictionary) -> void:
	var buttons = _get_all_slot_buttons()
	if index >= buttons.size():
		return
	
	var btn = buttons[index]
	if btn and btn.has_method("update_info"):
		btn.update_info(data)

# [New] Helper to traverse nested rows
func _get_all_slot_buttons() -> Array:
	var buttons = []
	for row in slot_container.get_children():
		if row is HBoxContainer:
			for btn in row.get_children():
				buttons.append(btn)
	return buttons
	
func _ensure_visible(_control: Control) -> void:
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
	
	# [New] Disable Split in 3/4
	if ProgressionManager.beats_per_bar == 3:
		split_bar_button.disabled = true
		split_bar_button.tooltip_text = "Not available in 3/4"
	else:
		split_bar_button.tooltip_text = "Split Selected Bar"


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
			EventBus.request_toggle_recording.emit()
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

# Context menu logic moved to SequenceContextMenu.gd

# ============================================================
# TILE CLICK HANDLER (INPUT WORKFLOW)
# ============================================================
func _on_tile_clicked(midi_note: int, string_index: int, _modifiers: Dictionary) -> void:
	# Check if we are in "Slot Editing Mode" (Sequence Slot Selected)
	var selected_idx = ProgressionManager.selected_index
	if selected_idx != -1:
		# If a slot is selected, clicking a tile opens the Pie Menu for that slot
		# centered on the mouse position (or tile position? Mouse is easier)
		var screen_pos = get_viewport().get_mouse_position()
		
		# Open Pie Menu with the clicked note as Root
		_open_pie_menu_impl(midi_note, string_index, screen_pos, selected_idx)


# ============================================================
# PIE MENU (RIGHT CLICK)
# ============================================================
func _on_tile_right_clicked(midi_note: int, string_index: int, world_pos: Vector3) -> void:
	var selected_idx = ProgressionManager.selected_index
	if selected_idx == -1:
		return
		
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var screen_pos = cam.unproject_position(world_pos)
	_open_pie_menu_impl(midi_note, string_index, screen_pos, selected_idx)

func _open_pie_menu_for_slot(slot_index: int) -> void:
	var data = ProgressionManager.get_slot(slot_index)
	var midi_note = data.get("root", 60)
	var string_idx = data.get("string", 5)
	
	_open_pie_menu_impl(midi_note, string_idx, get_viewport().get_mouse_position(), slot_index)

func _open_pie_menu_impl(midi_note: int, string_index: int, screen_pos: Vector2, slot_index: int) -> void:
	# Instantiate Pie Menu
	var pie = PieMenu.new()
	pie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to MainUI or this Control
	var main_ui = get_tree().get_first_node_in_group("main_ui")
	if main_ui:
		main_ui.add_child(pie)
	else:
		add_child(pie)
	
	pie.setup(screen_pos)
	
	# Handle Selection
	pie.chord_type_selected.connect(func(type):
		_apply_chord_from_tile(midi_note, string_index, type, slot_index)
	)
	
	# [New] Handle Hover Preview
	pie.chord_type_hovered.connect(func(type):
		if %Sequencer:
			# Preview needs to know we are editing a slot, not just hovering a tile
			# But preview_chord works with note/type/string, so it's fine.
			# However, we might want to mute the current slot playback if playing.
			%Sequencer.preview_chord(midi_note, type, string_index)
	)
	
	pie.chord_type_unhovered.connect(func():
		if %Sequencer:
			%Sequencer.clear_preview()
	)

	# Clear preview when the whole menu closes (if not selected)
	pie.closed.connect(func():
		if %Sequencer:
			%Sequencer.clear_preview()
	)

func set_ui_scale(value: float) -> void:
	if not is_node_ready():
		await ready
	
	var root = %RootMargin
	if root:
		if not root.resized.is_connected(_update_pivot):
			root.resized.connect(_update_pivot)
			
		# Apply only if changed
		if not is_equal_approx(root.scale.x, value):
			root.scale = Vector2(value, value)
			_update_pivot()

func _update_pivot() -> void:
	var root = %RootMargin
	if root:
		root.pivot_offset = Vector2(root.size.x / 2.0, root.size.y)

func _apply_chord_from_tile(midi_note: int, string_index: int, type: String, slot_index: int) -> void:
	# Update ProgressionManager
	var slot_data := {"root": midi_note, "type": type, "string": string_index}
	ProgressionManager.slots[slot_index] = slot_data
	ProgressionManager.slot_updated.emit(slot_index, slot_data)
	
	ProgressionManager.save_session()
	
	# Clear selection
	ProgressionManager.selected_index = -1
	ProgressionManager.selection_cleared.emit()
	
	# Visual/Audio feedback
	if AudioEngine:
		AudioEngine.play_note(midi_note, string_index, "chord")

# [New] Helper for Dynamic Scale Override on Selection
func _apply_scale_override_for_slot(data: Dictionary) -> void:
	var root = data.get("root", -1)
	var type = data.get("type", "")
	
	if root == -1: return
	
	# Check if Diatonic
	if MusicTheory.is_in_scale(root, GameManager.current_key, GameManager.current_mode):
		var expected = MusicTheory.get_diatonic_type(root, GameManager.current_key, GameManager.current_mode)
		# Power chords (5) are diatonic if expected is not diminished-ish
		if type == expected or (type == "5" and expected != "m7b5" and expected != "dim7"):
			GameManager.clear_scale_override()
		else:
			_apply_scale_override_logic(root, type)
	else:
		_apply_scale_override_logic(root, type)

func _apply_scale_override_logic(root: int, type: String) -> void:
	# Heuristic 1: Parallel Key (Major <-> Minor)
	var parallel_mode = MusicTheory.ScaleMode.MINOR if GameManager.current_mode == MusicTheory.ScaleMode.MAJOR else MusicTheory.ScaleMode.MAJOR
	
	# Check if root/chord fits in Parallel Scale
	if MusicTheory.is_in_scale(root, GameManager.current_key, parallel_mode):
		var expected = MusicTheory.get_diatonic_type(root, GameManager.current_key, parallel_mode)
		if type == expected or (type == "5" and expected != "m7b5" and expected != "dim7"):
			GameManager.set_scale_override(GameManager.current_key, parallel_mode)
			return

	# Heuristic 2: Chord Scale (Root + Major/Minor)
	var target_mode = MusicTheory.ScaleMode.MAJOR
	if "m" in type and not "dim" in type and not "maj" in type:
		target_mode = MusicTheory.ScaleMode.MINOR
	elif "dim" in type:
		target_mode = MusicTheory.ScaleMode.LOCRIAN
	
	GameManager.set_scale_override(root % 12, target_mode)
