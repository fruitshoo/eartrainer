class_name SequenceUIInputChords
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func handle_tile_right_clicked(midi_note: int, string_index: int, world_pos: Vector3) -> void:
	var selected_idx = ProgressionManager.selected_index
	if selected_idx == -1:
		return

	var camera = panel.get_viewport().get_camera_3d()
	if not camera:
		return

	var screen_pos = camera.unproject_position(world_pos)
	var selected_data: Dictionary = ProgressionManager.get_chord_data(selected_idx)
	var target_midi: int = midi_note
	var target_string: int = string_index
	if not selected_data.is_empty():
		target_midi = int(selected_data.get("root", midi_note))
		target_string = int(selected_data.get("string", string_index))
	open_quick_menu(target_midi, target_string, screen_pos, selected_idx)

func open_quick_menu_for_slot(slot_index: int) -> void:
	var data = ProgressionManager.get_slot(slot_index)
	var midi_note = data.get("root", 60)
	var string_idx = data.get("string", 5)
	open_quick_menu(midi_note, string_idx, panel.get_viewport().get_mouse_position(), slot_index)

func open_quick_menu(midi_note: int, string_index: int, screen_pos: Vector2, slot_index: int) -> void:
	var pie = PieMenu.new()
	pie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var main_ui = panel.get_tree().get_first_node_in_group("main_ui")
	if main_ui:
		main_ui.add_child(pie)
	else:
		panel.add_child(pie)

	pie.setup(screen_pos)
	pie.chord_type_selected.connect(func(chord_type: String):
		apply_chord_from_tile(midi_note, string_index, chord_type, slot_index)
	)

	pie.chord_type_hovered.connect(func(chord_type: String):
		var sequencer = _get_sequencer()
		if sequencer:
			var preview_type: String = chord_type
			if chord_type == "auto":
				preview_type = MusicTheory.get_diatonic_type(midi_note, GameManager.current_key, GameManager.current_mode)
			if chord_type != "clear":
				sequencer.preview_chord(midi_note, preview_type, string_index)
	)
	pie.chord_type_unhovered.connect(func():
		var sequencer = _get_sequencer()
		if sequencer:
			sequencer.clear_preview()
	)
	pie.closed.connect(func():
		var sequencer = _get_sequencer()
		if sequencer:
			sequencer.clear_preview()
	)

func apply_chord_from_tile(midi_note: int, string_index: int, chord_type: String, slot_index: int) -> void:
	if chord_type == "clear":
		ProgressionManager.clear_slot(slot_index)
		return

	var resolved_type: String = chord_type
	if chord_type == "auto":
		resolved_type = MusicTheory.get_diatonic_type(midi_note, GameManager.current_key, GameManager.current_mode)

	var slot_data := {"root": midi_note, "type": resolved_type, "string": string_index}
	ProgressionManager.set_slot_data(slot_index, slot_data)
	ProgressionManager.selected_index = slot_index
	panel._update_chord_editor()

	if AudioEngine:
		AudioEngine.play_note(midi_note, string_index, "chord")

func _get_sequencer():
	return panel.get_node_or_null("%Sequencer")
