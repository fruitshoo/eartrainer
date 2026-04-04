class_name ProgressionManagerMelody
extends RefCounted

var manager

func _init(p_manager) -> void:
	manager = p_manager

func set_melody_note(bar_idx: int, beat: int, sub: int, note_data: Dictionary) -> void:
	if bar_idx < 0 or bar_idx >= manager.bar_count:
		return

	if not manager.melody_events.has(bar_idx):
		manager.melody_events[bar_idx] = {}

	var key = "%d_%d" % [beat, sub]
	manager.melody_events[bar_idx][key] = note_data
	manager.melody_updated.emit(bar_idx)
	manager.save_session()

func clear_melody_note(bar_idx: int, beat: int, sub: int) -> void:
	if not manager.melody_events.has(bar_idx):
		return

	var key = "%d_%d" % [beat, sub]
	if manager.melody_events[bar_idx].has(key):
		manager.melody_events[bar_idx].erase(key)
		manager.melody_updated.emit(bar_idx)
		manager.save_session()

func get_melody_events(bar_idx: int) -> Dictionary:
	return manager.melody_events.get(bar_idx, {})

func replace_all_melody_events(new_events: Dictionary) -> void:
	var changed_bars := {}
	for bar_idx in manager.melody_events.keys():
		changed_bars[int(bar_idx)] = true

	manager.melody_events.clear()

	for bar_key in new_events.keys():
		var bar_idx = int(bar_key)
		if bar_idx < 0 or bar_idx >= manager.bar_count:
			continue

		var bar_data = new_events[bar_key]
		if not (bar_data is Dictionary):
			continue

		var copied_bar := {}
		for event_key in bar_data.keys():
			var note_data = bar_data[event_key]
			if note_data is Dictionary:
				copied_bar[str(event_key)] = note_data.duplicate(true)

		if not copied_bar.is_empty():
			manager.melody_events[bar_idx] = copied_bar
			changed_bars[bar_idx] = true

	for bar_idx in changed_bars.keys():
		manager.melody_updated.emit(int(bar_idx))
	manager.save_session()

func clear_all_melody() -> void:
	manager.melody_events.clear()
	for i in range(manager.bar_count):
		manager.melody_updated.emit(i)
	manager.save_session()
