class_name MelodyManagerRecording
extends RefCounted

var manager

func _init(p_manager) -> void:
	manager = p_manager

func on_sequencer_stopped() -> void:
	if manager.is_recording:
		stop_recording()
	manager._last_beat_time = -1.0
	manager._release_all_visuals()

func start_recording() -> void:
	if not get_sequencer():
		return
	manager.sync_from_progression()
	manager.is_recording = true
	manager.recording_started.emit()
	print("[MelodyManager] Recording Started")

func stop_recording() -> void:
	manager.is_recording = false
	manager.active_notes.clear()
	manager.sync_from_progression()
	manager.recording_stopped.emit()
	print("[MelodyManager] Recording Stopped. Total Notes: ", manager.recorded_notes.size())

func toggle_recording() -> void:
	if manager.is_recording:
		stop_recording()
	else:
		start_recording()

func on_tile_pressed(midi_note: int, string_index: int) -> void:
	if not manager.is_recording:
		return

	var seq = get_sequencer()
	if not seq or not seq.is_playing:
		return

	var state = seq.get_playback_state()
	var now = Time.get_ticks_msec()
	var elapsed_ms = now - state.last_beat_time
	var beat_duration_ms = (60.0 / state.bpm) * 1000.0
	var offset_beat = clampf(elapsed_ms / beat_duration_ms, 0.0, 1.0)
	var start_beat_global = float(state.beat) + offset_beat
	var snapped_beat = roundf(start_beat_global / manager.QUANTIZE_GRID) * manager.QUANTIZE_GRID

	var note_key = "%d_%d" % [midi_note, string_index]
	manager.active_notes[note_key] = {
		"step": state.step,
		"start_beat": snapped_beat,
		"raw_start_ms": now,
		"pitch": midi_note,
		"string": string_index
	}

	manager.visual_note_on.emit(midi_note, string_index)
	AudioEngine.play_note(midi_note, string_index)

func on_tile_released(midi_note: int, string_index: int) -> void:
	if not manager.is_recording:
		return

	var note_key = "%d_%d" % [midi_note, string_index]
	if not manager.active_notes.has(note_key):
		return

	var start_data = manager.active_notes[note_key]
	manager.active_notes.erase(note_key)

	var seq = get_sequencer()
	if not seq:
		return
	var state = seq.get_playback_state()

	var bpm = state.bpm
	var beat_ms = (60.0 / bpm) * 1000.0
	var now = Time.get_ticks_msec()
	var duration_beat = (now - start_data.raw_start_ms) / beat_ms
	var snapped_dur = maxf(roundf(duration_beat / manager.QUANTIZE_GRID) * manager.QUANTIZE_GRID, manager.QUANTIZE_GRID)

	var new_note = {
		"step": start_data.step,
		"start_beat": start_data.start_beat,
		"duration": snapped_dur,
		"pitch": midi_note,
		"string": string_index
	}

	manager.recorded_notes.append(new_note)
	if is_instance_valid(ProgressionManager):
		ProgressionManager.replace_all_melody_events(manager._build_melody_events_from_recorded_notes(manager.recorded_notes))
	manager.visual_note_off.emit(midi_note, string_index)

func get_sequencer() -> Node:
	var seqs = manager.get_tree().get_nodes_in_group("sequencer")
	if seqs.size() > 0:
		return seqs[0]
	return null
