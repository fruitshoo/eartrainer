class_name SequenceUIMelody
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func on_melody_slot_clicked(bar: int, beat: int, sub: int) -> void:
	ProgressionManager.selected_index = -1
	set_selected_melody_slot(bar, beat, sub)

	var events = ProgressionManager.get_melody_events(bar)
	var key = "%d_%d" % [beat, sub]
	var data = events.get(key, {})
	if not data.is_empty() and not data.get("is_sustain", false):
		panel._is_dragging_melody = true
		panel._drag_source_data = data.duplicate()
	else:
		panel._is_dragging_melody = false

func on_melody_ruler_clicked(bar: int, beat: int, sub: int) -> void:
	var slot_idx = get_slot_index_for_melody_position(bar, beat)
	if slot_idx < 0:
		return
	var slot_bar = ProgressionManager.get_bar_index_for_slot(slot_idx)
	var slot_start = ProgressionManager.get_slot_index_for_bar(slot_bar)
	var slot_offset = slot_idx - slot_start
	var density = max(1, ProgressionManager.bar_densities[slot_bar])
	var beats_per_slot = max(1, int(ProgressionManager.beats_per_bar / density))
	var beat_in_slot = beat - (slot_offset * beats_per_slot)
	panel._on_slot_beat_clicked(slot_idx, beat_in_slot, sub)

func on_melody_slot_right_clicked(bar: int, beat: int, sub: int) -> void:
	ProgressionManager.clear_melody_note(bar, beat, sub)
	panel._is_erasing_melody = true

func on_melody_slot_hovered(bar: int, beat: int, sub: int) -> void:
	if panel._is_erasing_melody:
		ProgressionManager.clear_melody_note(bar, beat, sub)
		return
	if not panel._is_dragging_melody:
		return

	var current_note = panel._drag_source_data.get("root", -1)
	if current_note != -1:
		var sustain_data = panel._drag_source_data.duplicate()
		sustain_data["is_sustain"] = true
		ProgressionManager.set_melody_note(bar, beat, sub, sustain_data)

func on_melody_slot_drag_released() -> void:
	panel._is_dragging_melody = false
	panel._is_erasing_melody = false
	panel._drag_source_data = {}

func highlight_melody_selected() -> void:
	for m_btn in panel._melody_slot_lookup.values():
		if m_btn and m_btn.has_method("set_highlight"):
			var is_sel = (
				m_btn.bar_index == panel.selected_melody_slot.get("bar", -1)
				and m_btn.beat_index == panel.selected_melody_slot.get("beat", -1)
				and m_btn.sub_index == panel.selected_melody_slot.get("sub", -1)
			)
			m_btn.set_highlight(is_sel)

func set_selected_melody_slot(bar: int, beat: int, sub: int) -> void:
	panel.selected_melody_slot = {"bar": bar, "beat": beat, "sub": sub}
	highlight_melody_selected()
	refresh_melody_context()

func clear_selected_melody_slot() -> void:
	panel.selected_melody_slot = {}
	highlight_melody_selected()
	refresh_melody_context()

func refresh_melody_context() -> void:
	if panel.selected_melody_slot.is_empty():
		panel._melody_context_slot_index = -1
		panel._update_all_slots_visual_state()
		panel._update_bar_tools_state()
		panel._restore_non_melody_harmonic_context()
		return

	var bar = int(panel.selected_melody_slot.get("bar", -1))
	var beat = int(panel.selected_melody_slot.get("beat", -1))
	panel._melody_context_slot_index = get_slot_index_for_melody_position(bar, beat)
	panel._update_all_slots_visual_state()
	panel._update_bar_tools_state()

	var data = ProgressionManager.get_chord_data(panel._melody_context_slot_index)
	if data.is_empty():
		GameManager.clear_scale_override()
		var sequencer = _get_sequencer()
		if sequencer and sequencer.has_method("_clear_chord_highlights"):
			sequencer.call("_clear_chord_highlights")
		return

	panel._apply_scale_override_for_slot(data)
	var sequencer = _get_sequencer()
	if sequencer:
		sequencer.preview_chord(int(data.get("root", 60)), str(data.get("type", "M")), int(data.get("string", 0)))

func get_slot_index_for_melody_position(bar: int, beat: int) -> int:
	if bar < 0 or bar >= ProgressionManager.bar_count:
		return -1
	var slot_index = ProgressionManager.get_slot_index_for_bar(bar)
	if slot_index < 0:
		return -1
	var density = max(1, ProgressionManager.bar_densities[bar])
	if density == 1:
		return slot_index
	var beats_per_slot = max(1, int(ProgressionManager.beats_per_bar / density))
	var slot_offset = clampi(int(floor(float(beat) / float(beats_per_slot))), 0, density - 1)
	return slot_index + slot_offset

func advance_melody_selection() -> void:
	var bar = panel.selected_melody_slot["bar"]
	var beat = panel.selected_melody_slot["beat"]
	var sub = panel.selected_melody_slot["sub"]

	sub += 1
	if sub >= 2:
		sub = 0
		beat += 1
		if beat >= ProgressionManager.beats_per_bar:
			beat = 0
			bar += 1
			if bar >= ProgressionManager.bar_count:
				GameLogger.info("[SequenceUI] Melody mode exited - end of sequence reached.")
				panel._awaiting_sub_note = false
				clear_selected_melody_slot()
				return

	set_selected_melody_slot(bar, beat, sub)

func regress_melody_selection() -> void:
	if panel.selected_melody_slot.is_empty():
		return
	var bar = panel.selected_melody_slot["bar"]
	var beat = panel.selected_melody_slot["beat"]
	var sub = panel.selected_melody_slot["sub"]

	sub -= 1
	if sub < 0:
		sub = 1
		beat -= 1
		if beat < 0:
			beat = ProgressionManager.beats_per_bar - 1
			bar -= 1
			if bar < 0:
				bar = 0
				beat = 0
				sub = 0

	set_selected_melody_slot(bar, beat, sub)

func on_melody_updated(bar_idx: int) -> void:
	var melody_slots = panel._melody_slots_by_bar.get(bar_idx, [])
	if melody_slots.is_empty():
		return

	var events = ProgressionManager.get_melody_events(bar_idx)
	for m_btn in melody_slots:
		var key = "%d_%d" % [m_btn.beat_index, m_btn.sub_index]
		var data = events.get(key, {})
		m_btn.update_info(data)
		apply_melody_roll_links(m_btn)

	if bar_idx > 0:
		refresh_melody_roll_links_for_bar(bar_idx - 1)
	if bar_idx < ProgressionManager.bar_count - 1:
		refresh_melody_roll_links_for_bar(bar_idx + 1)
	panel._update_bar_tools_state()

func refresh_all_melody_slots() -> void:
	for i in range(ProgressionManager.bar_count):
		on_melody_updated(i)

func refresh_melody_roll_links_for_bar(bar_idx: int) -> void:
	var melody_slots = panel._melody_slots_by_bar.get(bar_idx, [])
	for m_btn in melody_slots:
		apply_melody_roll_links(m_btn)

func apply_melody_roll_links(m_btn: Control) -> void:
	if not m_btn or not m_btn.has_method("set_roll_links"):
		return
	var current = get_melody_event(m_btn.bar_index, m_btn.beat_index, m_btn.sub_index)
	if current.is_empty():
		m_btn.set_roll_links(false, false)
		return
	var prev_pos = get_adjacent_melody_position(m_btn.bar_index, m_btn.beat_index, m_btn.sub_index, -1)
	var next_pos = get_adjacent_melody_position(m_btn.bar_index, m_btn.beat_index, m_btn.sub_index, 1)
	var prev_event = get_event_at_position(prev_pos)
	var next_event = get_event_at_position(next_pos)
	var connect_left = current.get("is_sustain", false) and is_same_melody_chain(current, prev_event)
	var connect_right = next_event.get("is_sustain", false) and is_same_melody_chain(current, next_event)
	m_btn.set_roll_links(connect_left, connect_right)

func get_melody_event(bar: int, beat: int, sub: int) -> Dictionary:
	var events = ProgressionManager.get_melody_events(bar)
	return events.get("%d_%d" % [beat, sub], {})

func get_event_at_position(position: Dictionary) -> Dictionary:
	if position.is_empty():
		return {}
	return get_melody_event(position["bar"], position["beat"], position["sub"])

func get_adjacent_melody_position(bar: int, beat: int, sub: int, direction: int) -> Dictionary:
	var next_bar = bar
	var next_beat = beat
	var next_sub = sub + direction
	if next_sub >= 2:
		next_sub = 0
		next_beat += 1
	elif next_sub < 0:
		next_sub = 1
		next_beat -= 1
	if next_beat >= ProgressionManager.beats_per_bar:
		next_beat = 0
		next_bar += 1
	elif next_beat < 0:
		next_bar -= 1
		if next_bar < 0:
			return {}
		next_beat = ProgressionManager.beats_per_bar - 1
	if next_bar < 0 or next_bar >= ProgressionManager.bar_count:
		return {}
	return {"bar": next_bar, "beat": next_beat, "sub": next_sub}

func is_same_melody_chain(current: Dictionary, neighbor: Dictionary) -> bool:
	if current.is_empty() or neighbor.is_empty():
		return false
	return int(current.get("root", -1)) == int(neighbor.get("root", -1)) and int(current.get("string", -1)) == int(neighbor.get("string", -1))

func on_step_beat_changed(step: int, beat: int, sub_beat: int) -> void:
	update_timeline_playhead(step, beat, sub_beat)
	update_melody_playhead(step, beat, sub_beat)

func update_timeline_playhead(step: int, beat: int, sub_beat: int) -> void:
	for tracked_bar in panel._timeline_slots_by_bar.keys():
		var timeline_slot = panel._timeline_slots_by_bar.get(tracked_bar)
		if timeline_slot and timeline_slot.has_method("update_playhead_progress"):
			timeline_slot.update_playhead_progress(0.0, -1.0)
	if step < 0 or beat < 0:
		return
	var bar_idx = ProgressionManager.get_bar_index_for_slot(step)
	if bar_idx < 0:
		return
	for tracked_bar in panel._timeline_slots_by_bar.keys():
		var timeline_slot = panel._timeline_slots_by_bar.get(tracked_bar)
		if not timeline_slot or not timeline_slot.has_method("update_playhead_progress"):
			continue
		var tracked_bar_idx = int(tracked_bar)
		if tracked_bar_idx < bar_idx:
			timeline_slot.update_playhead_progress(1.0, -1.0)
		elif tracked_bar_idx > bar_idx:
			timeline_slot.update_playhead_progress(0.0, -1.0)
	var timeline_slot = panel._timeline_slots_by_bar.get(bar_idx)
	if timeline_slot and timeline_slot.has_method("update_playhead_progress"):
		var exact_progress = (float(beat) + (float(sub_beat) * 0.5)) / float(max(ProgressionManager.beats_per_bar, 1))
		timeline_slot.update_playhead_progress(exact_progress, exact_progress)

func update_timeline_playhead_smooth() -> void:
	var sequencer = _get_sequencer()
	if not sequencer or not sequencer.is_playing:
		return
	var tick_duration_ms = int(((60.0 / GameManager.bpm) / 2.0) * 1000.0)
	if tick_duration_ms <= 0:
		return
	var elapsed_ms = Time.get_ticks_msec() - sequencer._last_tick_time_ms
	var local_progress = clampf(float(elapsed_ms) / float(tick_duration_ms), 0.0, 1.0)
	var bar_idx = ProgressionManager.get_bar_index_for_slot(sequencer.current_step)
	if bar_idx < 0:
		return
	var step_start = ProgressionManager.get_slot_index_for_bar(bar_idx)
	var density = max(1, ProgressionManager.bar_densities[bar_idx])
	var beats_per_slot = float(ProgressionManager.beats_per_bar) / float(density)
	var slot_offset = float(sequencer.current_step - step_start)
	var beat_in_bar = (slot_offset * beats_per_slot) + float(sequencer.current_beat) + (float(sequencer._sub_beat) * 0.5)
	var bar_progress = (beat_in_bar + (local_progress * 0.5)) / float(max(ProgressionManager.beats_per_bar, 1))
	var timeline_slot = panel._timeline_slots_by_bar.get(bar_idx)
	if timeline_slot and timeline_slot.has_method("update_playhead_progress"):
		timeline_slot.update_playhead_progress(bar_progress, bar_progress)

func update_melody_playhead(step: int, beat: int, sub_beat: int) -> void:
	if not panel._active_melody_playhead_key.is_empty():
		var previous_slot = panel._melody_slot_lookup.get(panel._active_melody_playhead_key)
		if previous_slot and previous_slot.has_method("set_playhead_active"):
			previous_slot.set_playhead_active(false)
	panel._active_melody_playhead_key = ""
	if step < 0 or beat < 0:
		return
	var position = get_melody_position_for_step(step, beat, sub_beat)
	if position.is_empty():
		return
	var melody_key = panel._get_melody_slot_key(position["bar"], position["beat"], position["sub"])
	var slot = panel._melody_slot_lookup.get(melody_key)
	if slot and slot.has_method("set_playhead_active"):
		slot.set_playhead_active(true)
		panel._active_melody_playhead_key = melody_key
	set_melody_playing_bar(position.get("bar", -1))

func get_melody_position_for_step(step: int, beat: int, sub_beat: int) -> Dictionary:
	var bar_idx = ProgressionManager.get_bar_index_for_slot(step)
	if bar_idx < 0:
		return {}
	var start_slot = ProgressionManager.get_slot_index_for_bar(bar_idx)
	var slot_offset = step - start_slot
	var density = max(1, ProgressionManager.bar_densities[bar_idx])
	var beats_per_slot = float(ProgressionManager.beats_per_bar) / density
	var beat_in_bar = beat + int(slot_offset * beats_per_slot)
	return {"bar": bar_idx, "beat": beat_in_bar, "sub": sub_beat}

func set_melody_playing_bar(bar_idx: int) -> void:
	for tracked_bar in panel._melody_slots_by_bar.keys():
		var is_active_bar = int(tracked_bar) == bar_idx
		var slots = panel._melody_slots_by_bar.get(tracked_bar, [])
		for slot in slots:
			if slot and slot.has_method("set_bar_playing"):
				slot.set_bar_playing(is_active_bar)

func _get_sequencer():
	return panel.get_node_or_null("%Sequencer")
