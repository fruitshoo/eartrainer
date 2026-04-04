class_name SequencerVisuals
extends RefCounted

var sequencer

func _init(p_sequencer) -> void:
	sequencer = p_sequencer

func preview_chord(root: int, chord_type: String, string_idx: int) -> void:
	clear_all_highlights()
	var data = {"root": root, "type": chord_type, "string": string_idx}
	visualize_slot_chord(data)

func clear_preview() -> void:
	clear_all_highlights()
	if not sequencer.is_playing:
		var data = ProgressionManager.get_slot(sequencer.current_step)
		if data:
			visualize_slot_chord(data)

func play_slot_strum() -> void:
	var data = ProgressionManager.get_slot(sequencer.current_step)
	if data:
		play_chord_internal(data, sequencer.PLAYBACK_STYLE_STRUM)

func play_block_chord() -> void:
	var data = ProgressionManager.get_chord_data(sequencer.current_step)
	if not data.is_empty():
		play_chord_internal(data, sequencer.PLAYBACK_STYLE_BLOCK)

func play_chord_internal(data: Dictionary, requested_style: String) -> void:
	if data.is_empty():
		return

	var accent_volume := get_current_accent_volume()
	var root_fret := MusicTheory.get_fret_position(data.root, data.string)
	var voicing_key := MusicTheory.get_voicing_key(data.string)
	var offsets: Array = MusicTheory.VOICING_SHAPES.get(voicing_key, {}).get(data.type, [[0, 0]])

	var is_power_chord: bool = (data.type == "5")
	var actual_style = sequencer.PLAYBACK_STYLE_BLOCK if is_power_chord else requested_style

	for offset in offsets:
		var target_string: int = data.string + offset[0]
		var target_fret: int = root_fret + offset[1]

		var tile = GameManager.find_tile(target_string, target_fret)
		if tile and is_instance_valid(tile):
			AudioEngine.play_note(tile.midi_note, tile.string_index, "chord", accent_volume)
			tile.apply_sequencer_highlight(null)
			sequencer._highlighted_chord_tiles.append(tile)

		if actual_style == sequencer.PLAYBACK_STYLE_STRUM:
			await sequencer.get_tree().create_timer(sequencer.STRUM_DELAY_SEC).timeout

func get_current_accent_volume() -> float:
	if sequencer.current_beat == 0 and sequencer._sub_beat == 0:
		return sequencer.ACCENT_VOLUME_STRONG
	elif sequencer._sub_beat != 0:
		return sequencer.ACCENT_VOLUME_WEAK
	else:
		return sequencer.ACCENT_VOLUME_NORMAL

func visualize_slot_chord(data: Dictionary) -> void:
	var root_fret := MusicTheory.get_fret_position(data.root, data.string)
	var voicing_key := MusicTheory.get_voicing_key(data.string)
	var offsets: Array = MusicTheory.VOICING_SHAPES.get(voicing_key, {}).get(data.type, [[0, 0]])

	for offset in offsets:
		var target_string: int = data.string + offset[0]
		var target_fret: int = root_fret + offset[1]

		var tile = GameManager.find_tile(target_string, target_fret)
		if tile and is_instance_valid(tile):
			tile.apply_sequencer_highlight(null, 0.5)
			sequencer._highlighted_chord_tiles.append(tile)

func clear_all_highlights() -> void:
	clear_chord_highlights()
	clear_melody_highlights()

func clear_chord_highlights() -> void:
	for tile in sequencer._highlighted_chord_tiles:
		if is_instance_valid(tile):
			tile.clear_sequencer_highlight()
	sequencer._highlighted_chord_tiles.clear()

func clear_melody_highlights() -> void:
	if is_instance_valid(sequencer._active_melody_tile):
		sequencer._active_melody_tile.clear_melody_highlight()
	sequencer._active_melody_tile = null

func handle_dynamic_scale_override(data: Dictionary) -> void:
	var root = data.get("root", -1)
	var chord_type = data.get("type", "")

	if root == -1:
		return
	var override_info = MusicTheory.get_visual_scale_override(root, chord_type, GameManager.current_key, GameManager.current_mode)
	if override_info.get("use_override", false):
		GameManager.set_scale_override(
			int(override_info.get("key", root % 12)),
			int(override_info.get("mode", GameManager.current_mode)),
			1 if override_info.get("use_flats", false) else 0
		)
	else:
		GameManager.clear_scale_override()

func play_melody_note() -> void:
	if not sequencer.is_playing:
		return

	var bar_idx = ProgressionManager.get_bar_index_for_slot(sequencer.current_step)
	if bar_idx == -1:
		return

	var events = ProgressionManager.get_melody_events(bar_idx)
	if events.is_empty():
		return

	var start_slot = ProgressionManager.get_slot_index_for_bar(bar_idx)
	var slot_offset = sequencer.current_step - start_slot
	var density = ProgressionManager.bar_densities[bar_idx]
	if density == 0:
		density = 1
	var beats_per_slot = float(ProgressionManager.beats_per_bar) / density
	var beat_in_bar = sequencer.current_beat + int(slot_offset * beats_per_slot)

	var key = "%d_%d" % [beat_in_bar, sequencer._sub_beat]
	var note_data = events.get(key, {})

	if not note_data.is_empty():
		var root = note_data.get("root", 60)
		var string_idx = note_data.get("string", 1)
		var is_sustain = note_data.get("is_sustain", false)

		if is_sustain:
			if not is_instance_valid(sequencer._active_melody_tile):
				var tile = GameManager.find_tile(string_idx, MusicTheory.get_fret_position(root, string_idx))
				if tile:
					tile.apply_melody_highlight()
					sequencer._active_melody_tile = tile
		else:
			clear_melody_highlights()
			AudioEngine.play_note(root, string_idx, "melody", 1.0)

			var tile = GameManager.find_tile(string_idx, MusicTheory.get_fret_position(root, string_idx))
			if tile:
				tile.apply_melody_highlight()
				sequencer._active_melody_tile = tile

			if note_data.has("sub_note"):
				var sub = note_data["sub_note"]
				var sub_root = sub.get("root", 60)
				var sub_string = sub.get("string", 1)
				var half_tick = (60.0 / GameManager.bpm) / 4.0

				sequencer.get_tree().create_timer(half_tick).timeout.connect(func():
					if not sequencer.is_playing:
						return
					clear_melody_highlights()
					AudioEngine.play_note(sub_root, sub_string, "melody", 1.0)
					var sub_tile = GameManager.find_tile(sub_string, MusicTheory.get_fret_position(sub_root, sub_string))
					if sub_tile:
						sub_tile.apply_melody_highlight()
						sequencer._active_melody_tile = sub_tile
				)
	else:
		clear_melody_highlights()
