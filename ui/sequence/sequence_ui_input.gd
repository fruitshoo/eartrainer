class_name SequenceUIInput
extends RefCounted

const SEQUENCE_UI_INPUT_MELODY = preload("res://ui/sequence/sequence_ui_input_melody.gd")
const SEQUENCE_UI_INPUT_CHORDS = preload("res://ui/sequence/sequence_ui_input_chords.gd")

var panel
var _melody_helper: SequenceUIInputMelody
var _chord_helper: SequenceUIInputChords

func _init(p_panel) -> void:
	panel = p_panel
	_melody_helper = SEQUENCE_UI_INPUT_MELODY.new(panel)
	_chord_helper = SEQUENCE_UI_INPUT_CHORDS.new(panel)

func unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			EventBus.request_toggle_playback.emit()
			panel.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if not panel.selected_melody_slot.is_empty():
				GameLogger.info("[SequenceUI] Melody mode exited - ESC key pressed.")
				panel._awaiting_sub_note = false
				panel._clear_selected_melody_slot()
				panel.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE:
			if Input.is_key_pressed(KEY_SHIFT):
				clear_melody()
				panel.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			on_quantize_pressed()
			panel.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			if event.ctrl_pressed or event.meta_pressed:
				undo_melody()
				panel.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			if event.ctrl_pressed or event.meta_pressed:
				panel._copy_selected_bar()
				panel.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_V:
			if event.ctrl_pressed or event.meta_pressed:
				panel._paste_to_selected_bar()
				panel.get_viewport().set_input_as_handled()
		elif not panel.selected_melody_slot.is_empty():
			if event.keycode == KEY_D:
				if panel._awaiting_sub_note:
					panel._awaiting_sub_note = false
				panel._advance_melody_selection()
				panel.get_viewport().set_input_as_handled()
			elif event.keycode == KEY_A:
				if panel._awaiting_sub_note:
					panel._awaiting_sub_note = false
				panel._regress_melody_selection()
				panel.get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not panel.selected_melody_slot.is_empty():
			if panel.get_viewport().gui_get_hovered_control():
				return
			panel.get_tree().create_timer(0.02).timeout.connect(panel._handle_void_click_deferred.bind(Engine.get_frames_drawn()))

func clear_melody() -> void:
	_melody_helper.clear_melody()

func undo_melody() -> void:
	_melody_helper.undo_melody()

func on_quantize_pressed() -> void:
	_melody_helper.quantize_melody()

func on_selection_cleared() -> void:
	panel._highlight_selected(-1)
	panel._update_split_button_state()
	panel._update_chord_editor()
	panel._update_bar_tools_state()

func on_tile_clicked(midi_note: int, string_index: int, modifiers: Dictionary) -> void:
	panel._last_tile_click_frame = Engine.get_frames_drawn()
	GameLogger.info("[SequenceUI] _on_tile_clicked: note=%d, string=%d (Frame: %d)" % [midi_note, string_index, panel._last_tile_click_frame])
	_melody_helper.handle_tile_clicked(midi_note, string_index, modifiers)

func on_tile_released(_midi_note: int, _string_index: int) -> void:
	return

func on_tile_right_clicked(midi_note: int, string_index: int, world_pos: Vector3) -> void:
	panel._last_tile_click_frame = Engine.get_frames_drawn()
	if _melody_helper.handle_tile_right_clicked():
		return
	_chord_helper.handle_tile_right_clicked(midi_note, string_index, world_pos)

func open_pie_menu_for_slot(slot_index: int) -> void:
	_chord_helper.open_quick_menu_for_slot(slot_index)

func open_pie_menu_impl(midi_note: int, string_index: int, screen_pos: Vector2, slot_index: int) -> void:
	_chord_helper.open_quick_menu(midi_note, string_index, screen_pos, slot_index)

func apply_chord_from_tile(midi_note: int, string_index: int, chord_type: String, slot_index: int) -> void:
	_chord_helper.apply_chord_from_tile(midi_note, string_index, chord_type, slot_index)

func _get_sequencer():
	return _chord_helper._get_sequencer()
