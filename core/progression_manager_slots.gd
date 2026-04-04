class_name ProgressionManagerSlots
extends RefCounted

var manager

func _init(p_manager) -> void:
	manager = p_manager

func update_settings(new_bar_count: int) -> void:
	manager.bar_count = clampi(new_bar_count, 2, 16)

	if manager.bar_densities.size() != manager.bar_count:
		var new_densities: Array[int] = []
		for i in range(manager.bar_count):
			if i < manager.bar_densities.size():
				new_densities.append(manager.bar_densities[i])
			else:
				new_densities.append(1)
		manager.bar_densities = new_densities

	reconstruct_slots()
	manager.settings_updated.emit(manager.bar_count, 1)
	manager.save_session()

func set_time_signature(beats: int) -> void:
	if beats != 3 and beats != 4:
		return
	if manager.beats_per_bar == beats:
		return

	manager.beats_per_bar = beats
	if manager.beats_per_bar == 3:
		for i in range(manager.bar_densities.size()):
			if manager.bar_densities[i] > 1:
				manager.bar_densities[i] = 1

	reconstruct_slots()
	manager.settings_updated.emit(manager.bar_count, 1)
	manager.save_session()

func toggle_bar_split(bar_index: int) -> void:
	if bar_index < 0 or bar_index >= manager.bar_densities.size():
		return

	var bar_data_map = {}
	var current_slot_read = 0
	for i in range(manager.bar_densities.size()):
		var density = manager.bar_densities[i]
		var chords = []
		for k in range(density):
			var slot_idx = current_slot_read + k
			if slot_idx < manager.slots.size():
				chords.append(manager.slots[slot_idx])
		bar_data_map[i] = chords
		current_slot_read += density

	var current_bar_density = manager.bar_densities[bar_index]
	manager.bar_densities[bar_index] = 2 if current_bar_density == 1 else 1

	resize_slots()

	for i in range(manager.slots.size()):
		manager.slots[i] = null

	var current_slot_write = 0
	for i in range(manager.bar_count):
		var density = manager.bar_densities[i]
		var saved_chords = bar_data_map.get(i, [])
		for k in range(density):
			if k < saved_chords.size():
				manager.slots[current_slot_write + k] = saved_chords[k]
			manager.slot_updated.emit(current_slot_write + k, manager.slots[current_slot_write + k] if manager.slots[current_slot_write + k] else {})
		current_slot_write += density

	manager.settings_updated.emit(manager.bar_count, 1)
	manager.save_session()

func force_refresh_ui() -> void:
	manager.settings_updated.emit(manager.bar_count, 1)
	manager.loop_range_changed.emit(manager.loop_start_index, manager.loop_end_index)
	manager.section_labels_changed.emit()
	for i in range(manager.slots.size()):
		manager.slot_updated.emit(i, manager.slots[i] if manager.slots[i] else {})
	for i in range(manager.bar_count):
		manager.melody_updated.emit(i)

func get_section_label(bar_index: int) -> String:
	if bar_index < 0 or bar_index >= manager.bar_count:
		return ""
	return str(manager.section_labels.get(bar_index, ""))

func set_section_label(bar_index: int, label: String) -> void:
	if bar_index < 0 or bar_index >= manager.bar_count:
		return
	var normalized: String = label.strip_edges()
	if normalized.is_empty():
		manager.section_labels.erase(bar_index)
	else:
		manager.section_labels[bar_index] = normalized
	manager.section_labels_changed.emit()
	manager.save_session()

func clear_section_label(bar_index: int) -> void:
	if bar_index < 0 or bar_index >= manager.bar_count:
		return
	manager.section_labels.erase(bar_index)
	manager.section_labels_changed.emit()
	manager.save_session()

func get_loop_bar_range() -> Vector2i:
	if manager.loop_start_index < 0 or manager.loop_end_index < 0:
		return Vector2i(-1, -1)
	return Vector2i(
		get_bar_index_for_slot(manager.loop_start_index),
		get_bar_index_for_slot(manager.loop_end_index)
	)

func get_beats_for_slot(slot_index: int) -> int:
	var current_slot = 0
	for density in manager.bar_densities:
		var next_boundary = current_slot + density
		if slot_index < next_boundary:
			if density == 1:
				return manager.beats_per_bar
			return manager.beats_per_bar / 2
		current_slot = next_boundary
	return manager.beats_per_bar

func get_bar_index_for_slot(slot_index: int) -> int:
	var current_slot = 0
	for i in range(manager.bar_densities.size()):
		var density = manager.bar_densities[i]
		if slot_index < current_slot + density:
			return i
		current_slot += density
	return -1

func get_slot_index_for_bar(bar_index: int) -> int:
	if bar_index < 0 or bar_index >= manager.bar_densities.size():
		return -1

	var current_slot = 0
	for i in range(bar_index):
		current_slot += manager.bar_densities[i]
	return current_slot

func set_slot_from_tile(midi_note: int, string_index: int, is_shift: bool, is_alt: bool) -> void:
	if manager.selected_index < 0:
		return

	if manager.loop_start_index != -1 and manager.loop_end_index != -1:
		if manager.loop_start_index != manager.loop_end_index:
			return

	var chord_type := MusicTheory.get_diatonic_type(
		midi_note,
		GameManager.current_key,
		GameManager.current_mode
	)

	if is_shift:
		chord_type = "7"
	elif is_alt:
		chord_type = MusicTheory.toggle_quality(chord_type)

	var slot_data := {"root": midi_note, "type": chord_type, "string": string_index}
	set_slot_data(manager.selected_index, slot_data)

func set_slot_data(index: int, slot_data: Dictionary, clear_selection: bool = false) -> void:
	if index < 0 or index >= manager.slots.size():
		return
	manager.slots[index] = slot_data.duplicate(true)
	manager.slot_updated.emit(index, manager.slots[index])
	if clear_selection and manager.selected_index == index:
		manager.selected_index = -1
	manager.save_session()

func set_selected_slot_type(chord_type: String) -> void:
	if manager.selected_index < 0 or manager.selected_index >= manager.slots.size():
		return
	var current = get_chord_data(manager.selected_index)
	if current.is_empty():
		return
	current["type"] = chord_type
	set_slot_data(manager.selected_index, current)

func set_loop_range(start: int, end: int) -> void:
	if start < 0 or end < 0 or start > end or end >= manager.total_slots:
		return

	manager.loop_start_index = start
	manager.loop_end_index = end
	if manager.selected_index != -1:
		manager.selected_index = -1
		manager.selection_cleared.emit()

	manager.loop_range_changed.emit(manager.loop_start_index, manager.loop_end_index)
	manager.save_session()

func clear_loop_range() -> void:
	manager.loop_start_index = -1
	manager.loop_end_index = -1
	manager.loop_range_changed.emit(-1, -1)
	manager.save_session()

func get_slot(index: int) -> Variant:
	if index >= 0 and index < manager.slots.size():
		return manager.slots[index]
	return null

func get_chord_data(index: int) -> Dictionary:
	var slot_value = get_slot(index)
	if slot_value is Dictionary:
		return slot_value
	return {}

func clear_all() -> void:
	for i in range(manager.slots.size()):
		manager.slots[i] = null
		manager.slot_updated.emit(i, {})
	manager.selected_index = -1
	manager.save_session()

func clear_slot(index: int) -> void:
	if index >= 0 and index < manager.slots.size():
		manager.slots[index] = null
		manager.slot_updated.emit(index, {})
		if manager.selected_index == index:
			manager.selected_index = -1
			manager.selection_cleared.emit()
	manager.save_session()

func reconstruct_slots() -> void:
	var old_slots = manager.slots.duplicate()
	resize_slots()
	for i in range(min(old_slots.size(), manager.slots.size())):
		manager.slots[i] = old_slots[i]
		manager.slot_updated.emit(i, manager.slots[i] if manager.slots[i] else {})

func resize_slots() -> void:
	var new_total = manager.total_slots
	manager.slots.resize(new_total)

	if manager.selected_index >= new_total:
		manager.selected_index = -1

	if manager.loop_end_index >= new_total:
		manager.clear_loop_range()

func _get_bar_snapshot(bar_index: int) -> Dictionary:
	var density: int = manager.bar_densities[bar_index]
	var slot_start: int = get_slot_index_for_bar(bar_index)
	var chords: Array = []
	for i in range(density):
		var slot_data = manager.slots[slot_start + i]
		if slot_data is Dictionary:
			chords.append(slot_data.duplicate(true))
		else:
			chords.append(null)

	return {
		"density": density,
		"chords": chords,
		"melody": manager.get_melody_events(bar_index).duplicate(true),
		"section_label": get_section_label(bar_index)
	}

func _apply_bar_snapshots(bar_snapshots: Array) -> void:
	manager.bar_densities.clear()
	for snapshot in bar_snapshots:
		var density: int = int(snapshot.get("density", 1))
		if manager.beats_per_bar == 3:
			density = 1
		manager.bar_densities.append(clampi(density, 1, 2))

	resize_slots()
	for slot_index in range(manager.slots.size()):
		manager.slots[slot_index] = null

	manager.section_labels.clear()
	manager.melody_events.clear()

	var write_slot: int = 0
	for bar_index in range(bar_snapshots.size()):
		var snapshot_value = bar_snapshots[bar_index]
		var snapshot: Dictionary = snapshot_value if snapshot_value is Dictionary else {}
		var density: int = manager.bar_densities[bar_index]
		var chords_value = snapshot.get("chords", [])
		var chords: Array = chords_value if chords_value is Array else []
		for chord_offset in range(density):
			var slot_value = chords[chord_offset] if chord_offset < chords.size() else null
			if slot_value is Dictionary:
				manager.slots[write_slot + chord_offset] = slot_value.duplicate(true)
			else:
				manager.slots[write_slot + chord_offset] = null
			manager.slot_updated.emit(write_slot + chord_offset, manager.slots[write_slot + chord_offset] if manager.slots[write_slot + chord_offset] else {})

		var melody_value = snapshot.get("melody", {})
		var melody: Dictionary = melody_value.duplicate(true) if melody_value is Dictionary else {}
		if not melody.is_empty():
			manager.melody_events[bar_index] = melody
		manager.melody_updated.emit(bar_index)

		var section_label: String = str(snapshot.get("section_label", "")).strip_edges()
		if not section_label.is_empty():
			manager.section_labels[bar_index] = section_label

		write_slot += density

	manager.section_labels_changed.emit()
	manager.settings_updated.emit(manager.bar_count, 1)
	manager.loop_range_changed.emit(manager.loop_start_index, manager.loop_end_index)
