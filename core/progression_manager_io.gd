class_name ProgressionManagerIO
extends RefCounted

var manager
var storage = preload("res://core/progression_storage.gd").new()

func _init(p_manager) -> void:
	manager = p_manager

func load_preset_data(name: String) -> Dictionary:
	return storage.load_preset(name)

func flush_session_save() -> void:
	if not manager._save_pending:
		return
	manager._save_pending = false
	storage.save_session(serialize())

func load_session() -> void:
	var data = storage.load_session()
	if not data.is_empty():
		deserialize(data)

func serialize() -> Dictionary:
	return {
		"version": 2,
		"bar_count": manager.bar_count,
		"beats_per_bar": manager.beats_per_bar,
		"playback_mode": int(MusicTheory.ChordPlaybackMode.ONCE),
		"bar_densities": manager.bar_densities,
		"slots": manager.slots,
		"melody_events": manager.melody_events,
		"section_labels": manager.section_labels,
		"loop_start": manager.loop_start_index,
		"loop_end": manager.loop_end_index,
		"key": GameManager.current_key,
		"mode": GameManager.current_mode,
		"melody_tracks": []
	}

func deserialize(data: Dictionary) -> void:
	manager.bar_count = data.get("bar_count", 4)
	manager.beats_per_bar = data.get("beats_per_bar", 4)
	manager.playback_mode = MusicTheory.ChordPlaybackMode.ONCE

	var saved_densities = data.get("bar_densities", [])
	if saved_densities.size() > 0:
		manager.bar_densities.clear()
		for density in saved_densities:
			manager.bar_densities.append(int(density))
	else:
		manager.bar_densities.clear()
		for _i in range(manager.bar_count):
			manager.bar_densities.append(1)

	manager._resize_slots()

	for slot_idx in range(manager.slots.size()):
		manager.slots[slot_idx] = null

	var saved_slots = data.get("slots", [])
	for slot_idx in range(min(manager.slots.size(), saved_slots.size())):
		var slot_data = saved_slots[slot_idx]
		if slot_data is Dictionary:
			if slot_data.has("root"):
				slot_data["root"] = int(slot_data["root"])
			if slot_data.has("string"):
				slot_data["string"] = int(slot_data["string"])
			manager.slots[slot_idx] = slot_data.duplicate()
		else:
			manager.slots[slot_idx] = slot_data

	manager.loop_start_index = data.get("loop_start", -1)
	manager.loop_end_index = data.get("loop_end", -1)

	manager.section_labels.clear()
	var saved_section_labels = data.get("section_labels", {})
	if saved_section_labels is Dictionary:
		for bar_idx_key in saved_section_labels.keys():
			manager.section_labels[int(bar_idx_key)] = str(saved_section_labels[bar_idx_key])

	manager.melody_events.clear()
	var saved_melody = data.get("melody_events", {})
	if saved_melody is Dictionary:
		for bar_idx_str in saved_melody.keys():
			var bar_idx = int(bar_idx_str)
			manager.melody_events[bar_idx] = saved_melody[bar_idx_str]

	manager.settings_updated.emit(manager.bar_count, 1)
	manager.loop_range_changed.emit(manager.loop_start_index, manager.loop_end_index)
	manager.section_labels_changed.emit()

func get_preset_list() -> Array[Dictionary]:
	return storage.get_preset_list()

func save_preset(name: String) -> void:
	storage.save_preset(name, serialize())

func load_preset(name: String) -> void:
	var target_data = storage.load_preset(name)
	if target_data.is_empty():
		return

	if target_data.has("key") and target_data.has("mode"):
		GameManager.current_key = int(target_data["key"])
		GameManager.current_mode = int(target_data["mode"])
		EventBus.game_settings_changed.emit()

	deserialize(target_data)
	manager.save_session()
	print("[ProgressionManager] Preset loaded: ", name)

func delete_preset(name: String) -> void:
	storage.delete_preset(name)

func reorder_presets(from_idx: int, to_idx: int) -> void:
	storage.reorder_presets(from_idx, to_idx)
