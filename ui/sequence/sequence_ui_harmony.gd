class_name SequenceUIHarmony
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func restore_non_melody_harmonic_context() -> void:
	if ProgressionManager.selected_index >= 0:
		var selected_data = ProgressionManager.get_chord_data(ProgressionManager.selected_index)
		if not selected_data.is_empty():
			apply_global_chord_context(selected_data)
			panel._apply_scale_override_for_slot(selected_data)
			preview_harmonic_context(selected_data)
			return
	var sequencer = _get_sequencer()
	if sequencer and not EventBus.is_sequencer_playing:
		var paused_data = ProgressionManager.get_chord_data(sequencer.current_step)
		sequencer.clear_preview()
		if not paused_data.is_empty():
			apply_global_chord_context(paused_data)
			panel._apply_scale_override_for_slot(paused_data)
			preview_harmonic_context(paused_data)
			return
	GameManager.clear_scale_override()

func preview_harmonic_context(data: Dictionary) -> void:
	var sequencer = _get_sequencer()
	if data.is_empty() or not sequencer or EventBus.is_sequencer_playing:
		return
	sequencer.preview_chord(int(data.get("root", 60)), str(data.get("type", "M")), int(data.get("string", 0)))

func apply_global_chord_context(data: Dictionary) -> void:
	if data.is_empty():
		return
	GameManager.current_chord_root = int(data.get("root", GameManager.current_chord_root))
	GameManager.current_chord_type = str(data.get("type", GameManager.current_chord_type))

func clear_harmonic_preview() -> void:
	var sequencer = _get_sequencer()
	if sequencer and not EventBus.is_sequencer_playing:
		sequencer.clear_preview()

func update_chord_editor() -> void:
	if panel.chord_editor_panel:
		panel.chord_editor_panel.visible = false

func update_chord_type_button_states(data: Dictionary) -> void:
	for key in panel._chord_type_buttons.keys():
		var btn: Button = panel._chord_type_buttons[key]
		if btn == null:
			continue
		var is_active = false
		if key == "auto" and not data.is_empty():
			var expected = MusicTheory.get_diatonic_type(int(data.get("root", 60)), GameManager.current_key, GameManager.current_mode)
			is_active = str(data.get("type", "")) == expected
		elif data.is_empty():
			is_active = false
		else:
			is_active = str(data.get("type", "")) == key
		btn.modulate = Color(1.12, 1.12, 0.92) if is_active else Color(1, 1, 1, 1)

func apply_inline_chord_type(chord_type: String) -> void:
	if ProgressionManager.selected_index < 0:
		return
	ProgressionManager.set_selected_slot_type(chord_type)

func apply_auto_chord_type() -> void:
	var idx = ProgressionManager.selected_index
	if idx < 0:
		return
	var data = ProgressionManager.get_chord_data(idx)
	if data.is_empty():
		return
	var auto_type = MusicTheory.get_diatonic_type(int(data.get("root", 60)), GameManager.current_key, GameManager.current_mode)
	data["type"] = auto_type
	ProgressionManager.set_slot_data(idx, data)

func clear_selected_chord() -> void:
	if ProgressionManager.selected_index < 0:
		return
	ProgressionManager.clear_slot(ProgressionManager.selected_index)

func _get_sequencer():
	return panel.get_node_or_null("%Sequencer")
