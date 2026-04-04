class_name SequenceUIInputMelody
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func clear_melody() -> void:
	var button = panel.get_node_or_null("%ClearMelodyButton")
	if button:
		var tween = panel.create_tween()
		tween.tween_property(button, "modulate", Color.RED, 0.1)
		tween.tween_property(button, "modulate", Color.WHITE, 0.1)

	GameLogger.info("[SequenceUI] _clear_melody() button pressed. Clearing all melody data.")
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("clear_melody"):
		melody_manager.clear_melody()
	else:
		ProgressionManager.clear_all_melody()

	if not panel.selected_melody_slot.is_empty():
		GameLogger.info("[SequenceUI] Selection cleared via Clear button.")
		panel._awaiting_sub_note = false
		panel._clear_selected_melody_slot()

	for i in range(ProgressionManager.bar_count):
		panel._on_melody_updated(i)

func undo_melody() -> void:
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("undo_last_note"):
		melody_manager.undo_last_note()

func quantize_melody() -> void:
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("quantize_notes"):
		melody_manager.quantize_notes()

func handle_tile_clicked(midi_note: int, string_index: int, modifiers: Dictionary) -> bool:
	if panel.selected_melody_slot.is_empty():
		return false

	var is_shift = modifiers.get("shift", false)
	if panel._awaiting_sub_note:
		var sub_data = {"root": midi_note, "string": string_index, "duration": 0.25}
		var bar = panel.selected_melody_slot["bar"]
		var beat = panel.selected_melody_slot["beat"]
		var sub = panel.selected_melody_slot["sub"]
		var events = ProgressionManager.get_melody_events(bar)
		var key = "%d_%d" % [beat, sub]
		var existing = events.get(key, {})
		if not existing.is_empty():
			existing["sub_note"] = sub_data
			ProgressionManager.set_melody_note(bar, beat, sub, existing)
		panel._awaiting_sub_note = false
		panel._advance_melody_selection()
		panel.get_viewport().set_input_as_handled()
		return true

	if is_shift:
		var sixteenth = {"root": midi_note, "string": string_index, "duration": 0.25}
		ProgressionManager.set_melody_note(
			panel.selected_melody_slot["bar"],
			panel.selected_melody_slot["beat"],
			panel.selected_melody_slot["sub"],
			sixteenth
		)
		panel._awaiting_sub_note = true
		panel.get_viewport().set_input_as_handled()
		return true

	var is_ctrl = modifiers.get("ctrl", false) or modifiers.get("meta", false)
	if is_ctrl:
		var quarter = {"root": midi_note, "string": string_index, "duration": 1.0}
		ProgressionManager.set_melody_note(
			panel.selected_melody_slot["bar"],
			panel.selected_melody_slot["beat"],
			panel.selected_melody_slot["sub"],
			quarter
		)
		panel._advance_melody_selection()
		if not panel.selected_melody_slot.is_empty():
			var sustain = quarter.duplicate()
			sustain["is_sustain"] = true
			ProgressionManager.set_melody_note(
				panel.selected_melody_slot["bar"],
				panel.selected_melody_slot["beat"],
				panel.selected_melody_slot["sub"],
				sustain
			)
			panel._advance_melody_selection()
		panel.get_viewport().set_input_as_handled()
		return true

	var note_data = {"root": midi_note, "string": string_index, "duration": 0.5}
	ProgressionManager.set_melody_note(
		panel.selected_melody_slot["bar"],
		panel.selected_melody_slot["beat"],
		panel.selected_melody_slot["sub"],
		note_data
	)
	panel._advance_melody_selection()
	panel.get_viewport().set_input_as_handled()
	return true

func handle_tile_right_clicked() -> bool:
	if panel.selected_melody_slot.is_empty():
		return false

	if panel._awaiting_sub_note:
		panel._awaiting_sub_note = false

	var bar = panel.selected_melody_slot["bar"]
	var events = ProgressionManager.get_melody_events(bar)
	var key = "%d_%d" % [panel.selected_melody_slot["beat"], panel.selected_melody_slot["sub"]]

	if not events.has(key):
		panel._regress_melody_selection()
		bar = panel.selected_melody_slot["bar"]
		key = "%d_%d" % [panel.selected_melody_slot["beat"], panel.selected_melody_slot["sub"]]

	var existing = events.get(key, {})
	if existing.has("sub_note"):
		existing.erase("sub_note")
		existing["duration"] = 0.5
		ProgressionManager.set_melody_note(bar, panel.selected_melody_slot["beat"], panel.selected_melody_slot["sub"], existing)
	else:
		ProgressionManager.clear_melody_note(bar, panel.selected_melody_slot["beat"], panel.selected_melody_slot["sub"])
	panel.get_viewport().set_input_as_handled()
	return true
