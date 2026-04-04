class_name SequenceUISlots
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func on_slot_clicked(index: int) -> void:
	if index >= ProgressionManager.total_slots:
		return

	if not panel.selected_melody_slot.is_empty():
		GameLogger.info("[SequenceUI] Melody mode exited - Chord Slot %d clicked." % index)
		panel._awaiting_sub_note = false
		panel._clear_selected_melody_slot()

	if Input.is_key_pressed(KEY_SHIFT):
		if ProgressionManager.selected_index != -1:
			var start = min(ProgressionManager.selected_index, index)
			var end = max(ProgressionManager.selected_index, index)
			ProgressionManager.set_loop_range(start, end)
		else:
			ProgressionManager.selected_index = index
			ProgressionManager.clear_loop_range()
	else:
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index
		var is_loop_active = loop_start != -1 and loop_end != -1

		if is_loop_active:
			ProgressionManager.clear_loop_range()
		else:
			if ProgressionManager.selected_index == index:
				ProgressionManager.selected_index = -1
			else:
				panel._awaiting_sub_note = false
				panel._clear_selected_melody_slot()
				ProgressionManager.selected_index = index

	update_split_button_state()

func on_slot_beat_clicked(slot_idx: int, beat_idx: int, sub_idx: int = 0) -> void:
	var sequencer = _get_sequencer()
	if sequencer:
		sequencer.seek(slot_idx, beat_idx, sub_idx)
	ProgressionManager.selected_index = -1

func on_slot_right_clicked(index: int) -> void:
	if ProgressionManager.beats_per_bar == 3:
		return
	var bar_idx = ProgressionManager.get_bar_index_for_slot(index)
	if bar_idx < 0:
		return
	ProgressionManager.selected_index = -1
	ProgressionManager.toggle_bar_split(bar_idx)
	update_split_button_state()

func on_loop_range_changed(_start: int, _end: int) -> void:
	highlight_selected(ProgressionManager.selected_index)
	update_loop_overlay()

func update_loop_overlay() -> void:
	if not panel.loop_overlay_panel:
		return
	var start = ProgressionManager.loop_start_index
	var end = ProgressionManager.loop_end_index
	var buttons = panel._get_all_slot_buttons()
	panel.loop_overlay_panel.update_overlay(buttons, start, end)

func highlight_selected(selected_idx: int) -> void:
	update_all_slots_visual_state()
	panel._update_chord_editor()
	panel._update_bar_tools_state()

	if selected_idx >= 0:
		var data = ProgressionManager.get_chord_data(selected_idx)
		if not data.is_empty():
			panel._apply_scale_override_for_slot(data)
			panel._preview_harmonic_context(data)
		else:
			GameManager.clear_scale_override()
			panel._clear_harmonic_preview()
	else:
		if panel.selected_melody_slot.is_empty():
			panel._restore_non_melody_harmonic_context()
		else:
			GameManager.clear_scale_override()

func highlight_playing(playing_step: int) -> void:
	panel._current_playing_step = playing_step
	panel._current_playing_bar = ProgressionManager.get_bar_index_for_slot(playing_step)
	update_all_slots_visual_state()
	panel._set_melody_playing_bar(panel._current_playing_bar)

func update_all_slots_visual_state() -> void:
	var children = panel._get_all_slot_buttons()
	var loop_start = ProgressionManager.loop_start_index
	var loop_end = ProgressionManager.loop_end_index
	var selected_idx = ProgressionManager.selected_index
	var is_loop_active = loop_start != -1 and loop_end != -1

	for i in range(children.size()):
		var btn = children[i]
		if not btn.has_method("set_state"):
			continue

		var is_playing = i == panel._current_playing_step
		var bar_idx = ProgressionManager.get_bar_index_for_slot(i)
		var is_playing_bar = bar_idx == panel._current_playing_bar
		var is_selected = i == selected_idx or (selected_idx == -1 and i == panel._melody_context_slot_index)
		var is_in_loop = false
		if is_loop_active and i >= loop_start and i <= loop_end:
			is_in_loop = true

		btn.set_state(is_playing, is_selected, is_in_loop, is_playing_bar)
		if is_playing and btn.is_inside_tree():
			panel._ensure_visible(btn)

func update_split_button_state() -> void:
	if not panel.split_bar_button:
		return

	var idx = ProgressionManager.selected_index
	if idx < 0:
		panel.split_bar_button.disabled = true
		panel.split_bar_button.text = "Split/Merge Bar"
		return

	panel.split_bar_button.disabled = false
	var bar_idx = ProgressionManager.get_bar_index_for_slot(idx)
	var density = ProgressionManager.bar_densities[bar_idx]
	panel.split_bar_button.text = "Merge Bar" if density == 2 else "Split Bar"

	if ProgressionManager.beats_per_bar == 3:
		panel.split_bar_button.disabled = true
		panel.split_bar_button.tooltip_text = "Not available in 3/4"
	else:
		panel.split_bar_button.tooltip_text = "Split Selected Bar"

func _get_sequencer():
	return panel.get_node_or_null("%Sequencer")
