# sequence_ui.gd
# 시퀀서 UI 컨트롤러 (슬롯 선택, 재생 버튼, 설정 등)
extends Control

# ============================================================
# EXPORTS & CONSTANTS
# ============================================================
var slot_button_scene: PackedScene = preload("res://ui/sequence/slot_button.tscn")
var timeline_ruler_scene: PackedScene = preload("res://ui/sequence/timeline_ruler_slot.tscn")
const SEQUENCE_UI_STYLES = preload("res://ui/sequence/sequence_ui_styles.gd")
const SEQUENCE_UI_HARMONY = preload("res://ui/sequence/sequence_ui_harmony.gd")
const SEQUENCE_UI_SLOTS = preload("res://ui/sequence/sequence_ui_slots.gd")
const SEQUENCE_UI_MELODY = preload("res://ui/sequence/sequence_ui_melody.gd")
const SEQUENCE_UI_INPUT = preload("res://ui/sequence/sequence_ui_input.gd")
const SEQUENCE_UI_CONTROLS = preload("res://ui/sequence/sequence_ui_controls.gd")
const SEQUENCE_UI_LAYOUT = preload("res://ui/sequence/sequence_ui_layout.gd")
const SEQUENCE_UI_BAR_CLIPBOARD = preload("res://ui/sequence/sequence_ui_bar_clipboard.gd")
const BAR_WIDTH := 164.0
const BAR_WIDTH_COMPACT := 146.0
const BAR_WIDTH_DENSE := 122.0
const SYSTEM_BAR_COUNT := 4
const CHORD_SLOT_HEIGHT := 38.0
const CHORD_SLOT_HEIGHT_COMPACT := 34.0
const TIMELINE_ROW_HEIGHT := 20.0
const MELODY_SLOT_HEIGHT := 68.0
const MELODY_SLOT_HEIGHT_COMPACT := 52.0
const HEADER_ROW_HEIGHT := 16.0
const HEADER_ROW_HEIGHT_COMPACT := 12.0
const SINGLE_ROW_SCROLL_HEIGHT := 174.0
const DOUBLE_ROW_SCROLL_HEIGHT := 332.0
const INLINE_CHORD_TYPES := ["M", "m", "7", "M7", "m7", "5", "dim", "sus4"]
const SECTION_PRESET_LABELS := ["Clear", "Intro", "Verse", "Pre", "Chorus", "Bridge", "Solo", "Outro"]
const TOOLBAR_PILL_BG := ThemeColors.APP_BUTTON_BG
const TOOLBAR_PILL_BG_HOVER := ThemeColors.APP_BUTTON_BG_HOVER
const TOOLBAR_PILL_BG_PRESSED := ThemeColors.APP_BUTTON_BG_PRESSED
const TOOLBAR_PILL_BORDER := ThemeColors.APP_BUTTON_BORDER
const TOOLBAR_PILL_TEXT := ThemeColors.APP_TEXT

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var slot_container: Container = %SlotContainer
@onready var loop_overlay_panel: SequenceLoopOverlay = %LoopOverlayPanel
@onready var context_menu: SequenceContextMenu

# Controls
@onready var bar_count_spin_box: SpinBox = %BarCountSpinBox
@onready var time_sig_button: Button = %TimeSigButton # [New]
@onready var copy_bar_button: Button = %CopyBarButton
@onready var paste_bar_button: Button = %PasteBarButton
@onready var chord_editor_panel: PanelContainer = %ChordEditorPanel
@onready var chord_editor_label: Label = %ChordEditorLabel
@onready var library_button: Button = %LibraryButton

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

# [New] 16th Note State
var _awaiting_sub_note: bool = false

var _last_tile_click_frame: int = -1
var _slot_buttons: Array = []
var _timeline_slots_by_bar: Dictionary = {}
var _melody_slots_by_bar: Dictionary = {}
var _melody_slot_lookup: Dictionary = {}
var _chord_type_buttons: Dictionary = {}
var _melody_context_slot_index: int = -1
var _active_melody_playhead_key: String = ""
var _style_helper: SequenceUIStyles
var _harmony_helper: SequenceUIHarmony
var _slot_helper: SequenceUISlots
var _melody_helper: SequenceUIMelody
var _input_helper: SequenceUIInput
var _controls_helper: SequenceUIControls
var _layout_helper: SequenceUILayout
var _bar_clipboard_helper: SequenceUIBarClipboard
var _section_context_menu: PopupMenu
var _section_context_bar_index: int = -1


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	if _style_helper == null:
		_style_helper = SEQUENCE_UI_STYLES.new(self)
	if _harmony_helper == null:
		_harmony_helper = SEQUENCE_UI_HARMONY.new(self)
	if _slot_helper == null:
		_slot_helper = SEQUENCE_UI_SLOTS.new(self)
	if _melody_helper == null:
		_melody_helper = SEQUENCE_UI_MELODY.new(self)
	if _input_helper == null:
		_input_helper = SEQUENCE_UI_INPUT.new(self)
	if _controls_helper == null:
		_controls_helper = SEQUENCE_UI_CONTROLS.new(self)
	if _layout_helper == null:
		_layout_helper = SEQUENCE_UI_LAYOUT.new(self)
	if _bar_clipboard_helper == null:
		_bar_clipboard_helper = SEQUENCE_UI_BAR_CLIPBOARD.new(self)
	add_to_group("sequence_ui")
	_setup_signals()
	_setup_controls()
	_setup_context_menu()
	_apply_soft_panel_styles()
	
	_sync_ui_from_manager()
	_rebuild_slots()

func _process(_delta: float) -> void:
	if _melody_helper:
		_melody_helper.update_timeline_playhead_smooth()

func _use_compact_layout() -> bool:
	return ProgressionManager.bar_count > SYSTEM_BAR_COUNT

func _use_dense_layout() -> bool:
	return ProgressionManager.bar_count > 8

func _get_system_bar_count() -> int:
	return 8 if _use_dense_layout() else SYSTEM_BAR_COUNT

func _get_bar_width() -> float:
	if _use_dense_layout():
		return BAR_WIDTH_DENSE
	return BAR_WIDTH_COMPACT if _use_compact_layout() else BAR_WIDTH

func _get_chord_slot_height() -> float:
	if _use_dense_layout():
		return 30.0
	return CHORD_SLOT_HEIGHT_COMPACT if _use_compact_layout() else CHORD_SLOT_HEIGHT

func _get_melody_slot_height() -> float:
	return MELODY_SLOT_HEIGHT_COMPACT if _use_compact_layout() else MELODY_SLOT_HEIGHT

func _get_header_row_height() -> float:
	if _use_dense_layout():
		return 10.0
	return HEADER_ROW_HEIGHT_COMPACT if _use_compact_layout() else HEADER_ROW_HEIGHT

func _get_system_spacing() -> int:
	if _use_dense_layout():
		return 6
	return 8 if _use_compact_layout() else 12

func _get_row_spacing() -> int:
	if _use_dense_layout():
		return 3
	return 4 if _use_compact_layout() else 6

func _get_scroll_target_height() -> float:
	var system_count := int(ceil(float(ProgressionManager.bar_count) / float(_get_system_bar_count())))
	system_count = max(system_count, 1)
	var per_system: float = _get_header_row_height() + TIMELINE_ROW_HEIGHT + _get_chord_slot_height() + (float(_get_row_spacing()) * 2.0)
	var total_height: float = 18.0 + (per_system * float(system_count)) + (float(_get_system_spacing()) * float(max(system_count - 1, 0)))
	if system_count <= 2:
		return total_height
	var max_height: float = 246.0 if _use_dense_layout() else (320.0 if _use_compact_layout() else 188.0)
	return min(total_height, max_height)

func _handle_void_click_deferred(captured_frame: int) -> void:
	# Use the specific frame index captured when the event originated for the check.
	if _last_tile_click_frame >= captured_frame:
		return
		
	# Additional Safety: Check if we are hovering a Control (UI)
	var hovered = get_viewport().gui_get_hovered_control()
	if hovered:
		GameLogger.info("[SequenceUI] Void click ignored - hovering UI: %s" % hovered.name)
		return

	# Otherwise, clear the selection and exit melody mode.
	var mouse_pos = get_viewport().get_mouse_position()
	GameLogger.info("[SequenceUI] Melody input exited via VOID click (Pos: %v, Frame: %d/%d)." % [mouse_pos, captured_frame, Engine.get_frames_drawn()])
	_awaiting_sub_note = false
	_clear_selected_melody_slot()


func _setup_signals() -> void:
	ProgressionManager.slot_selected.connect(_highlight_selected)
	ProgressionManager.slot_updated.connect(_update_slot_label)
	ProgressionManager.selection_cleared.connect(_on_selection_cleared)
	ProgressionManager.settings_updated.connect(_on_settings_updated)
	ProgressionManager.loop_range_changed.connect(_on_loop_range_changed)
	ProgressionManager.melody_updated.connect(_on_melody_updated)
	ProgressionManager.section_labels_changed.connect(_rebuild_slots)

	GameManager.settings_changed.connect(_sync_ui_from_manager)
	
	EventBus.bar_changed.connect(_highlight_playing)
	EventBus.sequencer_step_beat_changed.connect(_on_step_beat_changed)
	EventBus.request_close_library.connect(_close_library_panel)
	
	EventBus.tile_right_clicked.connect(_on_tile_right_clicked)
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.tile_released.connect(_on_tile_released)

func _setup_controls() -> void:
	_controls_helper.setup_controls()

func _apply_soft_panel_styles() -> void:
	_style_helper.apply_soft_panel_styles()

func _build_panel_style(fill_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	return _style_helper.build_panel_style(fill_color, border_color, radius)

func _apply_toolbar_button_style(button: Button, compact: bool) -> void:
	_style_helper.apply_toolbar_button_style(button, compact)

func _apply_option_button_style(button: OptionButton) -> void:
	_style_helper.apply_option_button_style(button)

func _build_toolbar_pill_style(fill_color: Color, border_color: Color, radius: int, margin_x: int, margin_y: int, shadow_size: int) -> StyleBoxFlat:
	return _style_helper.build_toolbar_pill_style(fill_color, border_color, radius, margin_x, margin_y, shadow_size)


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
	var data = ProgressionManager.get_chord_data(index)
	if data.is_empty():
		return
	data["type"] = new_type
	ProgressionManager.set_slot_data(index, data)

# ============================================================
# UI LOGIC
# ============================================================


func _sync_ui_from_manager() -> void:
	_controls_helper.sync_ui_from_manager()

func _rebuild_slots() -> void:
	_layout_helper.rebuild_slots()

func _get_melody_slot_key(bar: int, beat: int, sub: int) -> String:
	return _layout_helper.get_melody_slot_key(bar, beat, sub)

func _get_slot_time_context_label(slot_idx: int) -> String:
	return _layout_helper.get_slot_time_context_label(slot_idx)

func _connect_slot_signals(btn: Control) -> void:
	_layout_helper.connect_slot_signals(btn)

# Removed _on_mode_toggle
# Removed _rebuild_melody_slots


func _on_melody_slot_clicked(bar: int, beat: int, sub: int) -> void:
	_melody_helper.on_melody_slot_clicked(bar, beat, sub)

func _on_melody_ruler_clicked(bar: int, beat: int, sub: int) -> void:
	_melody_helper.on_melody_ruler_clicked(bar, beat, sub)

func _on_timeline_beat_clicked(bar: int, beat: int, sub: int) -> void:
	_melody_helper.on_melody_ruler_clicked(bar, beat, sub)

func _on_melody_slot_right_clicked(bar: int, beat: int, sub: int) -> void:
	_melody_helper.on_melody_slot_right_clicked(bar, beat, sub)

func _on_melody_slot_hovered(bar: int, beat: int, sub: int) -> void:
	_melody_helper.on_melody_slot_hovered(bar, beat, sub)

func _on_melody_slot_drag_released() -> void:
	_melody_helper.on_melody_slot_drag_released()

func _highlight_melody_selected() -> void:
	_melody_helper.highlight_melody_selected()

func _set_selected_melody_slot(bar: int, beat: int, sub: int) -> void:
	_melody_helper.set_selected_melody_slot(bar, beat, sub)

func _clear_selected_melody_slot() -> void:
	_melody_helper.clear_selected_melody_slot()

func _refresh_melody_context() -> void:
	_melody_helper.refresh_melody_context()

func _restore_non_melody_harmonic_context() -> void:
	_harmony_helper.restore_non_melody_harmonic_context()

func _preview_harmonic_context(data: Dictionary) -> void:
	_harmony_helper.preview_harmonic_context(data)

func _apply_global_chord_context(data: Dictionary) -> void:
	_harmony_helper.apply_global_chord_context(data)

func _clear_harmonic_preview() -> void:
	_harmony_helper.clear_harmonic_preview()

func _get_slot_index_for_melody_position(bar: int, beat: int) -> int:
	return _melody_helper.get_slot_index_for_melody_position(bar, beat)

func _advance_melody_selection() -> void:
	_melody_helper.advance_melody_selection()

func _regress_melody_selection() -> void:
	_melody_helper.regress_melody_selection()

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
		
		# [Fix] Deselect after split/merge to prevent accidental chord changes
		# when the user intends to play melody immediately after.
		ProgressionManager.selected_index = -1

func _on_time_sig_pressed() -> void:
	var current = ProgressionManager.beats_per_bar
	var next = 3 if current == 4 else 4
	ProgressionManager.set_time_signature(next)

# func _on_bpm_changed(value: float) -> void: ... (Removed)

# ============================================================
# SLOT INTERACTION
# ============================================================
func _on_slot_clicked(index: int) -> void:
	_slot_helper.on_slot_clicked(index)

func _on_slot_beat_clicked(slot_idx: int, beat_idx: int, sub_idx: int = 0) -> void:
	_slot_helper.on_slot_beat_clicked(slot_idx, beat_idx, sub_idx)

func _on_slot_right_clicked(index: int) -> void:
	_slot_helper.on_slot_right_clicked(index)

func _on_loop_range_changed(_start: int, _end: int) -> void:
	_slot_helper.on_loop_range_changed(_start, _end)

func _update_loop_overlay() -> void:
	_slot_helper.update_loop_overlay()


# State tracking for highlight optimization
var _current_playing_step: int = -1
var _current_playing_bar: int = -1

func _highlight_selected(selected_idx: int) -> void:
	_slot_helper.highlight_selected(selected_idx)

func _highlight_playing(playing_step: int) -> void:
	_slot_helper.highlight_playing(playing_step)

func _update_all_slots_visual_state() -> void:
	_slot_helper.update_all_slots_visual_state()

func _on_melody_updated(bar_idx: int) -> void:
	_melody_helper.on_melody_updated(bar_idx)

func _update_slot_label(index: int, data: Dictionary) -> void:
	var buttons = _get_all_slot_buttons()
	if index >= buttons.size():
		return
	
	var btn = buttons[index]
	if btn and btn.has_method("update_info"):
		btn.update_info(data)
	if index == ProgressionManager.selected_index:
		_update_chord_editor()

# [New] Helper to traverse nested rows
func _get_all_slot_buttons() -> Array:
	return _slot_buttons

func _refresh_all_melody_slots() -> void:
	_melody_helper.refresh_all_melody_slots()

func _set_melody_playing_bar(bar_idx: int) -> void:
	_melody_helper.set_melody_playing_bar(bar_idx)

func _refresh_melody_roll_links_for_bar(bar_idx: int) -> void:
	_melody_helper.refresh_melody_roll_links_for_bar(bar_idx)

func _apply_melody_roll_links(m_btn: Control) -> void:
	_melody_helper.apply_melody_roll_links(m_btn)

func _get_melody_event(bar: int, beat: int, sub: int) -> Dictionary:
	return _melody_helper.get_melody_event(bar, beat, sub)

func _get_event_at_position(position: Dictionary) -> Dictionary:
	return _melody_helper.get_event_at_position(position)

func _get_adjacent_melody_position(bar: int, beat: int, sub: int, direction: int) -> Dictionary:
	return _melody_helper.get_adjacent_melody_position(bar, beat, sub, direction)

func _is_same_melody_chain(current: Dictionary, neighbor: Dictionary) -> bool:
	return _melody_helper.is_same_melody_chain(current, neighbor)
	
func _ensure_visible(_control: Control) -> void:
	# Basic visibility check logic
	# Since scrolling is manual or locked, we might want to auto scroll vertically if we had vertical scroll enabled.
	# But actually vertical scroll is disabled now? No, we re-enabled vertical but disabled horizontal?
	# Wait, user earlier said "Scroll appears".
	# If we have 2 rows, it expands.
	# But if it's very long, scroll might be useful.
	pass
			
func _on_step_beat_changed(step: int, beat: int, sub_beat: int) -> void:
	_melody_helper.on_step_beat_changed(step, beat, sub_beat)

func _update_melody_playhead(step: int, beat: int, sub_beat: int) -> void:
	_melody_helper.update_melody_playhead(step, beat, sub_beat)

func _update_timeline_playhead(step: int, beat: int, sub_beat: int) -> void:
	_melody_helper.update_timeline_playhead(step, beat, sub_beat)

func _get_melody_position_for_step(step: int, beat: int, sub_beat: int) -> Dictionary:
	return _melody_helper.get_melody_position_for_step(step, beat, sub_beat)

func _update_split_button_state() -> void:
	_slot_helper.update_split_button_state()

func _update_chord_editor() -> void:
	_harmony_helper.update_chord_editor()

func _update_chord_type_button_states(data: Dictionary) -> void:
	_harmony_helper.update_chord_type_button_states(data)

func _apply_inline_chord_type(chord_type: String) -> void:
	_harmony_helper.apply_inline_chord_type(chord_type)

func _apply_auto_chord_type() -> void:
	_harmony_helper.apply_auto_chord_type()

func _clear_selected_chord() -> void:
	_harmony_helper.clear_selected_chord()

func _get_active_bar_index() -> int:
	if ProgressionManager.selected_index >= 0:
		return ProgressionManager.get_bar_index_for_slot(ProgressionManager.selected_index)
	if not selected_melody_slot.is_empty():
		return int(selected_melody_slot.get("bar", -1))
	return -1

func _update_bar_tools_state() -> void:
	_controls_helper.update_bar_tools_state()

func _on_section_preset_selected(index: int) -> void:
	_controls_helper.on_section_preset_selected(index)

func _show_section_context_menu(bar_index: int, screen_position: Vector2) -> void:
	_section_context_bar_index = bar_index
	_controls_helper.show_section_context_menu(bar_index, screen_position)

func _on_section_context_menu_id_pressed(id: int) -> void:
	_controls_helper.on_section_context_menu_id_pressed(id)

func _copy_selected_bar() -> void:
	_controls_helper.copy_selected_bar()

func _paste_to_selected_bar() -> void:
	_controls_helper.paste_to_selected_bar()


# ============================================================
# INPUT & SIGNALS
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	_input_helper.unhandled_input(event)

# func _toggle_playback() ... Removed
# func _toggle_record_macro() ... Removed
# func _on_stop_button_pressed() ... Removed
# func _on_record_toggled() ... Removed

func _clear_melody() -> void:
	_input_helper.clear_melody()

func _undo_melody() -> void:
	_input_helper.undo_melody()

func _on_quantize_pressed() -> void:
	_input_helper.on_quantize_pressed()

# func _on_recording_started() ... Removed
# func _on_recording_stopped() ... Removed

func _on_selection_cleared():
	_input_helper.on_selection_cleared()

# Context menu logic moved to SequenceContextMenu.gd

# ============================================================
# TILE CLICK HANDLER (INPUT WORKFLOW)
# ============================================================
func _on_tile_clicked(midi_note: int, string_index: int, _modifiers: Dictionary) -> void:
	_input_helper.on_tile_clicked(midi_note, string_index, _modifiers)

func _on_tile_released(_midi_note: int, _string_index: int) -> void:
	_input_helper.on_tile_released(_midi_note, _string_index)


# ============================================================
# PIE MENU (RIGHT CLICK)
# ============================================================
func _on_tile_right_clicked(midi_note: int, string_index: int, world_pos: Vector3) -> void:
	_input_helper.on_tile_right_clicked(midi_note, string_index, world_pos)

func _open_pie_menu_for_slot(slot_index: int) -> void:
	_input_helper.open_pie_menu_for_slot(slot_index)

func _open_pie_menu_impl(midi_note: int, string_index: int, screen_pos: Vector2, slot_index: int) -> void:
	_input_helper.open_pie_menu_impl(midi_note, string_index, screen_pos, slot_index)

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
	_input_helper.apply_chord_from_tile(midi_note, string_index, type, slot_index)

# [New] Helper for Dynamic Scale Override on Selection
func _apply_scale_override_for_slot(data: Dictionary) -> void:
	var root = data.get("root", -1)
	var type = data.get("type", "")
	
	if root == -1: return
	var override_info = MusicTheory.get_visual_scale_override(root, type, GameManager.current_key, GameManager.current_mode)
	if override_info.get("use_override", false):
		GameManager.set_scale_override(
			int(override_info.get("key", root % 12)),
			int(override_info.get("mode", GameManager.current_mode)),
			1 if override_info.get("use_flats", false) else 0
		)
	else:
		GameManager.clear_scale_override()
