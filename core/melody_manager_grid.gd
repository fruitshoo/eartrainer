class_name MelodyManagerGrid
extends RefCounted

var manager

func _init(p_manager) -> void:
	manager = p_manager

func clear_melody() -> void:
	manager.recorded_notes.clear()
	manager.active_notes.clear()
	if is_instance_valid(ProgressionManager):
		ProgressionManager.clear_all_melody()
	print("[MelodyManager] Melody Cleared")

func undo_last_note() -> void:
	var target := find_last_anchor_note()
	if target.is_empty():
		print("[MelodyManager] Nothing to undo")
		return

	var bar = int(target["bar"])
	var beat = int(target["beat"])
	var sub = int(target["sub"])
	var events = ProgressionManager.get_melody_events(bar)
	var key = "%d_%d" % [beat, sub]
	var note_data = events.get(key, {})

	if note_data.has("sub_note"):
		note_data.erase("sub_note")
		note_data["duration"] = maxf(float(note_data.get("duration", 0.25)), 0.5)
		ProgressionManager.set_melody_note(bar, beat, sub, note_data)
	else:
		clear_note_chain(bar, beat, sub, note_data)

	sync_from_progression()
	print("[MelodyManager] Undo last melody note")

func quantize_notes(grid: float) -> void:
	sync_from_progression()
	print("[MelodyManager] Melody grid already quantized to %.2f-beat steps" % grid)

func import_recorded_notes(notes: Array) -> void:
	manager.recorded_notes.clear()
	manager.active_notes.clear()

	for note in notes:
		if note is Dictionary:
			manager.recorded_notes.append(note.duplicate(true))

	if is_instance_valid(ProgressionManager):
		ProgressionManager.replace_all_melody_events(build_melody_events_from_recorded_notes(manager.recorded_notes))

func sync_from_progression() -> void:
	manager.recorded_notes = extract_recorded_notes_from_progression()

func find_last_anchor_note() -> Dictionary:
	var last_note := {}
	var best_order := -1

	for bar in range(ProgressionManager.bar_count):
		var events = ProgressionManager.get_melody_events(bar)
		for event_key in events.keys():
			var note_data = events[event_key]
			if not (note_data is Dictionary) or note_data.get("is_sustain", false):
				continue

			var parts = str(event_key).split("_")
			if parts.size() != 2:
				continue

			var beat = int(parts[0])
			var sub = int(parts[1])
			var order = (bar * ProgressionManager.beats_per_bar * 2) + (beat * 2) + sub
			if order >= best_order:
				best_order = order
				last_note = {"bar": bar, "beat": beat, "sub": sub}

	return last_note

func clear_note_chain(bar: int, beat: int, sub: int, note_data: Dictionary) -> void:
	ProgressionManager.clear_melody_note(bar, beat, sub)

	var current = advance_position(bar, beat, sub)
	while not current.is_empty():
		var next_events = ProgressionManager.get_melody_events(current["bar"])
		var next_key = "%d_%d" % [current["beat"], current["sub"]]
		var next_note = next_events.get(next_key, {})
		if next_note.is_empty():
			break
		if not next_note.get("is_sustain", false):
			break
		if next_note.get("root", -1) != note_data.get("root", -1):
			break
		if next_note.get("string", -1) != note_data.get("string", -1):
			break

		ProgressionManager.clear_melody_note(current["bar"], current["beat"], current["sub"])
		current = advance_position(current["bar"], current["beat"], current["sub"])

func extract_recorded_notes_from_progression() -> Array[Dictionary]:
	var notes: Array[Dictionary] = []

	for bar in range(ProgressionManager.bar_count):
		var events = ProgressionManager.get_melody_events(bar)
		var ordered_keys = events.keys()
		ordered_keys.sort_custom(func(a, b): return melody_key_order(str(a)) < melody_key_order(str(b)))

		for event_key in ordered_keys:
			var note_data = events[event_key]
			if not (note_data is Dictionary) or note_data.get("is_sustain", false):
				continue

			var parts = str(event_key).split("_")
			if parts.size() != 2:
				continue

			var beat = int(parts[0])
			var sub = int(parts[1])
			var note_start = position_to_recorded_time(bar, beat, sub)
			if note_start.is_empty():
				continue

			var duration: float = 0.25 if float(note_data.get("duration", 0.5)) <= 0.25 else 0.5
			var current = advance_position(bar, beat, sub)
			while not current.is_empty():
				var next_events = ProgressionManager.get_melody_events(current["bar"])
				var next_key = "%d_%d" % [current["beat"], current["sub"]]
				var next_note = next_events.get(next_key, {})
				if next_note.is_empty():
					break
				if not next_note.get("is_sustain", false):
					break
				if next_note.get("root", -1) != note_data.get("root", -1):
					break
				if next_note.get("string", -1) != note_data.get("string", -1):
					break
				duration += 0.5
				current = advance_position(current["bar"], current["beat"], current["sub"])

			notes.append({
				"step": note_start["step"],
				"start_beat": note_start["start_beat"],
				"duration": duration,
				"pitch": int(note_data.get("root", 60)),
				"string": int(note_data.get("string", 1))
			})

			if note_data.has("sub_note"):
				var sub_note = note_data["sub_note"]
				notes.append({
					"step": note_start["step"],
					"start_beat": note_start["start_beat"] + 0.25,
					"duration": 0.25,
					"pitch": int(sub_note.get("root", 60)),
					"string": int(sub_note.get("string", 1))
				})

	return notes

func build_melody_events_from_recorded_notes(notes: Array[Dictionary]) -> Dictionary:
	var new_events := {}

	for note in notes:
		var start = recorded_note_to_position(note)
		if start.is_empty():
			continue

		var bar = int(start["bar"])
		var beat = int(start["beat"])
		var sub = int(start["sub"])
		var duration_slots = max(1, int(round(float(note.get("duration", 0.5)) / 0.5)))
		var note_data := {
			"root": int(note.get("pitch", 60)),
			"string": int(note.get("string", 1)),
			"duration": 0.25 if float(note.get("duration", 0.5)) <= 0.25 else (1.0 if duration_slots >= 2 else 0.5)
		}

		set_event(new_events, bar, beat, sub, note_data)

		var current = {"bar": bar, "beat": beat, "sub": sub}
		for _i in range(1, duration_slots):
			current = advance_position(current["bar"], current["beat"], current["sub"])
			if current.is_empty():
				break

			set_event(new_events, current["bar"], current["beat"], current["sub"], {
				"root": int(note.get("pitch", 60)),
				"string": int(note.get("string", 1)),
				"is_sustain": true,
				"duration": 0.5
			})

	return new_events

func recorded_note_to_position(note: Dictionary) -> Dictionary:
	var step = int(note.get("step", -1))
	if step < 0:
		return {}

	var bar = ProgressionManager.get_bar_index_for_slot(step)
	if bar == -1:
		return {}

	var start_slot = ProgressionManager.get_slot_index_for_bar(bar)
	var density = max(1, ProgressionManager.bar_densities[bar])
	var beats_per_slot = float(ProgressionManager.beats_per_bar) / density
	var slot_offset = step - start_slot
	var beat_in_bar = (slot_offset * beats_per_slot) + float(note.get("start_beat", 0.0))
	var snapped = clampi(int(round(beat_in_bar / 0.5)), 0, (ProgressionManager.beats_per_bar * 2) - 1)

	return {
		"bar": bar,
		"beat": snapped / 2,
		"sub": snapped % 2
	}

func position_to_recorded_time(bar: int, beat: int, sub: int) -> Dictionary:
	var density = max(1, ProgressionManager.bar_densities[bar])
	var beats_per_slot = float(ProgressionManager.beats_per_bar) / density
	var beat_in_bar = float(beat) + (float(sub) * 0.5)
	var slot_offset = int(floor(beat_in_bar / beats_per_slot))
	var step = ProgressionManager.get_slot_index_for_bar(bar) + slot_offset
	var start_beat = beat_in_bar - (slot_offset * beats_per_slot)

	return {
		"step": step,
		"start_beat": start_beat
	}

func advance_position(bar: int, beat: int, sub: int) -> Dictionary:
	var next_bar = bar
	var next_beat = beat
	var next_sub = sub + 1

	if next_sub >= 2:
		next_sub = 0
		next_beat += 1

	if next_beat >= ProgressionManager.beats_per_bar:
		next_beat = 0
		next_bar += 1

	if next_bar >= ProgressionManager.bar_count:
		return {}

	return {"bar": next_bar, "beat": next_beat, "sub": next_sub}

func set_event(target: Dictionary, bar: int, beat: int, sub: int, note_data: Dictionary) -> void:
	if not target.has(bar):
		target[bar] = {}
	target[bar]["%d_%d" % [beat, sub]] = note_data.duplicate(true)

func melody_key_order(key: String) -> int:
	var parts = key.split("_")
	if parts.size() != 2:
		return -1
	return (int(parts[0]) * 2) + int(parts[1])
