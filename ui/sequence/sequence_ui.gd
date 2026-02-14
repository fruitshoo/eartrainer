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

# [New] Melody UI
var melody_slot_scene: PackedScene = preload("res://ui/sequence/melody/melody_slot.tscn")
# melody_container removed (Unified View)
var selected_melody_slot: Dictionary = {} # {bar, beat, sub}

# [New] Drag State
var _is_dragging_melody: bool = false
var _is_erasing_melody: bool = false
var _drag_source_data: Dictionary = {}


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
	ProgressionManager.melody_updated.connect(_on_melody_updated)

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
		clear_melody_button.tooltip_text = "Clear All Melody (Shift+Del)"

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

	_refresh_all_melody_slots()
	
	# [New] Dynamic Grid Logic
	var total_bars = ProgressionManager.bar_count
	
	# 4마디 초과시 높이 확장 (2줄) - 트윈 애니메이션
	# 1줄 높이: 110px (80+24+2 + small margin), 2줄: 230px
	var scroll_container = %SequencerScroll
	if scroll_container:
		var target_height = 230.0 if total_bars > 4 else 110.0
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

func _rebuild_slots() -> void:
	# 1. Cleanup
	for child in slot_container.get_children():
		child.queue_free()
	
	# [New] Tighten spacing
	slot_container.add_theme_constant_override("separation", 0)
	
	# 2. Reconstruct (Unified View: Chord Row + Melody Row interleaved)
	var total_bars = ProgressionManager.bar_count
	var slot_global_index = 0
	
	var current_system_row: HBoxContainer
	
	# Iterate through each bar
	for i in range(total_bars):
		if i % 4 == 0:
			# New System Row (Group of 4 bars)
			current_system_row = HBoxContainer.new()
			current_system_row.add_theme_constant_override("separation", 10) # Gap between bars
			current_system_row.alignment = BoxContainer.ALIGNMENT_CENTER
			slot_container.add_child(current_system_row)
			
		var current_bar_idx = i
		
		# --- Bar Container (Locks Chord & Melody vertically) ---
		var bar_vbox = VBoxContainer.new()
		bar_vbox.add_theme_constant_override("separation", 2) # [Optimized] Vertical gap
		bar_vbox.custom_minimum_size.x = 164.0 # [Optimized] Base width for 2 chords + gap
		current_system_row.add_child(bar_vbox)
		
		# --- Chord Layer ---
		var chord_hbox = HBoxContainer.new()
		chord_hbox.add_theme_constant_override("separation", 4)
		chord_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar_vbox.add_child(chord_hbox)
		
		var density = ProgressionManager.bar_densities[current_bar_idx]
		for k in range(density):
			var slot_idx = slot_global_index
			slot_global_index += 1
			
			var btn = slot_button_scene.instantiate()
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Fill available bar width
			_connect_slot_signals(btn)
			chord_hbox.add_child(btn)
			
			btn.custom_minimum_size.y = 80 # Keep fixed height
			
			if btn.has_method("setup"):
				btn.setup(slot_idx, ProgressionManager.beats_per_bar if density == 1 else 2)
			
			var data = ProgressionManager.get_slot(slot_idx)
			if data and btn.has_method("update_info"):
				btn.update_info(data)
		
		# --- Melody Layer ---
		var melody_hbox = HBoxContainer.new()
		melody_hbox.add_theme_constant_override("separation", 0) # [New] Zero gap for visual continuity
		melody_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		melody_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL # [New] Ensure stable width
		bar_vbox.add_child(melody_hbox)
		
		var m_beats = ProgressionManager.beats_per_bar
		var m_subs = 2
		var total_m_slots = m_beats * m_subs
		var m_slot_width = 164.0 / total_m_slots
		
		for b in range(m_beats):
			for s in range(m_subs):
				var m_btn = melody_slot_scene.instantiate()
				m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				# [Fix] Force exact fixed width to prevent text from pushing layout
				m_btn.custom_minimum_size = Vector2(m_slot_width, 24)
				m_btn.clip_text = true
				
				melody_hbox.add_child(m_btn)
				
				if m_btn.has_method("setup"):
					m_btn.setup(current_bar_idx, b, s)
				
				var key = "%d_%d" % [b, s]
				var events = ProgressionManager.get_melody_events(current_bar_idx)
				var data = events.get(key, {})
				if m_btn.has_method("update_info"):
					m_btn.update_info(data)
				
				if m_btn.has_signal("melody_slot_clicked"):
					m_btn.melody_slot_clicked.connect(_on_melody_slot_clicked)
				if m_btn.has_signal("melody_slot_right_clicked"):
					m_btn.melody_slot_right_clicked.connect(_on_melody_slot_right_clicked)
				if m_btn.has_signal("melody_slot_hovered"):
					m_btn.melody_slot_hovered.connect(_on_melody_slot_hovered)
				if m_btn.has_signal("melody_slot_drag_released"):
					m_btn.melody_slot_drag_released.connect(_on_melody_slot_drag_released)
		
		# Spacer after group of 4
		if (i + 1) % 4 == 0 and (i + 1) < total_bars:
			var sep = Control.new()
			sep.custom_minimum_size.y = 12 # [Optimized] Tighter vertical gap between systems
			slot_container.add_child(sep)
		
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

# Removed _on_mode_toggle
# Removed _rebuild_melody_slots


func _on_melody_slot_clicked(bar: int, beat: int, sub: int) -> void:
	# [New] Mutual Exclusion: Selecting melody clears chord selection
	ProgressionManager.selected_index = -1
	
	selected_melody_slot = {"bar": bar, "beat": beat, "sub": sub}
	_highlight_melody_selected()
	
	# Start Drag
	var events = ProgressionManager.get_melody_events(bar)
	var key = "%d_%d" % [beat, sub]
	var data = events.get(key, {})
	
	if not data.is_empty() and not data.get("is_sustain", false):
		_is_dragging_melody = true
		_drag_source_data = data.duplicate()
	else:
		_is_dragging_melody = false

func _on_melody_slot_right_clicked(bar: int, beat: int, sub: int) -> void:
	ProgressionManager.clear_melody_note(bar, beat, sub)
	_is_erasing_melody = true

func _on_melody_slot_hovered(bar: int, beat: int, sub: int) -> void:
	if _is_erasing_melody:
		ProgressionManager.clear_melody_note(bar, beat, sub)
		return
		
	if not _is_dragging_melody: return
	
	# Extend Sustain
	var current_note = _drag_source_data.get("root", -1)
	if current_note != -1:
		var sustain_data = _drag_source_data.duplicate()
		sustain_data["is_sustain"] = true
		ProgressionManager.set_melody_note(bar, beat, sub, sustain_data)
		
		# Immediately update selection to the end of drag? 
		# Or keep it at the start. Let's keep it at start for now.
		# But we need to refresh UI. ProgressionManager.set_melody_note emits melody_updated.
		# _rebuild_slots is NOT called on melody_updated. We need a lighter way.

func _on_melody_slot_drag_released() -> void:
	_is_dragging_melody = false
	_is_erasing_melody = false
	_drag_source_data = {}

func _highlight_melody_selected() -> void:
	# Traverse unified container to find all MelodySlots
	for system_row in slot_container.get_children():
		if not system_row is HBoxContainer: continue
		
		for bar_vbox in system_row.get_children():
			if not bar_vbox is VBoxContainer: continue
			
			# Melody Layer is the SECOND child (index 1)
			if bar_vbox.get_child_count() > 1:
				var melody_hbox = bar_vbox.get_child(1)
				for m_btn in melody_hbox.get_children():
					if m_btn.has_method("set_highlight"):
						var is_sel = (m_btn.bar_index == selected_melody_slot.get("bar", -1) and 
									  m_btn.beat_index == selected_melody_slot.get("beat", -1) and 
									  m_btn.sub_index == selected_melody_slot.get("sub", -1))
						m_btn.set_highlight(is_sel)


func _advance_melody_selection() -> void:
	var bar = selected_melody_slot["bar"]
	var beat = selected_melody_slot["beat"]
	var sub = selected_melody_slot["sub"]
	
	sub += 1
	var subdivisions = 2 # 8th notes
	if sub >= subdivisions:
		sub = 0
		beat += 1
		if beat >= ProgressionManager.beats_per_bar:
			beat = 0
			bar += 1
			if bar >= ProgressionManager.bar_count:
				# End of sequence
				selected_melody_slot = {}
				_highlight_melody_selected()
				return
	
	selected_melody_slot = {"bar": bar, "beat": beat, "sub": sub}
	_highlight_melody_selected()

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
	
	# [New] Mutual Exclusion: Clear Melody Selection
	if not selected_melody_slot.is_empty():
		selected_melody_slot = {}
		_highlight_melody_selected()
	
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
				# [New] Mutual Exclusion: Selecting chord clears melody selection
				selected_melody_slot = {}
				_highlight_melody_selected()
				ProgressionManager.selected_index = index
	
	_update_split_button_state()

func _on_slot_beat_clicked(slot_idx: int, beat_idx: int) -> void:
	# [New] Cmd+Click on Beat also triggers Slot Selection (same as clicking slot)
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		_on_slot_clicked(slot_idx) # Delegate to slot click handler
		return
		
# [New] Seek Playhead (Normal Click)
	%Sequencer.seek(slot_idx, beat_idx)
	
	# [New] If we just clicked a beat to seek, and we aren't holding modifiers,
	# clear the chord selection to prevent "sticky" behavior while recording melody.
	ProgressionManager.selected_index = -1

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

func _on_melody_updated(bar_idx: int) -> void:
	# Find the Bar VBox for this index
	var current_bar_count = 0
	for system_row in slot_container.get_children():
		if not system_row is HBoxContainer: continue
		for bar_vbox in system_row.get_children():
			if not bar_vbox is VBoxContainer: continue
			
			if current_bar_count == bar_idx:
				# Target found. Second child is melody HBox
				if bar_vbox.get_child_count() > 1:
					var m_hbox = bar_vbox.get_child(1)
					var events = ProgressionManager.get_melody_events(bar_idx)
					for m_btn in m_hbox.get_children():
						var key = "%d_%d" % [m_btn.beat_index, m_btn.sub_index]
						var data = events.get(key, {})
						m_btn.update_info(data)
				return
			current_bar_count += 1

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
	for system_row in slot_container.get_children():
		if not system_row is HBoxContainer: continue
		
		for bar_vbox in system_row.get_children():
			if not bar_vbox is VBoxContainer: continue
			
			# Chord Layer is the FIRST child (index 0)
			if bar_vbox.get_child_count() > 0:
				var chord_hbox = bar_vbox.get_child(0)
				for btn in chord_hbox.get_children():
					if btn.has_signal("slot_pressed"):
						buttons.append(btn)
	return buttons

func _refresh_all_melody_slots() -> void:
	for i in range(ProgressionManager.bar_count):
		_on_melody_updated(i)
	
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
	# [New] Unified View Input Routing
	# If a Melody Slot is selected, input goes to Melody.
	if not selected_melody_slot.is_empty():
		var note_data = {
			"root": midi_note, 
			"string": string_index,
			"duration": 0.5
		}
		
		var bar = selected_melody_slot["bar"]
		var beat = selected_melody_slot["beat"]
		var sub = selected_melody_slot["sub"]
		
		ProgressionManager.set_melody_note(bar, beat, sub, note_data)
		_advance_melody_selection()
		return # [Exit] Don't process Chord Mode logic

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
