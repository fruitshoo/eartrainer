class_name SequencerPlayback
extends RefCounted

var sequencer

func _init(p_sequencer) -> void:
	sequencer = p_sequencer

func toggle_play() -> void:
	sequencer.is_playing = not sequencer.is_playing
	EventBus.is_sequencer_playing = sequencer.is_playing
	EventBus.sequencer_playing_changed.emit(sequencer.is_playing)

	if sequencer.is_playing:
		resume_playback()
	else:
		pause_playback()

func reset_position() -> void:
	if sequencer.is_playing:
		return

	sequencer.current_step = 0
	sequencer.current_beat = 0
	sequencer._sub_beat = 0
	sequencer._is_paused = false
	sequencer._last_tick_time_ms = 0
	sequencer._clear_all_highlights()
	EventBus.sequencer_step_beat_changed.emit(sequencer.current_step, sequencer.current_beat, sequencer._sub_beat)
	EventBus.beat_updated.emit(-1, ProgressionManager.beats_per_bar)
	EventBus.bar_changed.emit(sequencer.current_step)

func seek(step: int, beat: int, sub_beat: int = 0) -> void:
	sequencer.current_step = step
	sequencer.current_beat = beat
	sequencer._sub_beat = sub_beat
	sequencer._last_tick_time_ms = Time.get_ticks_msec()

	if sequencer.is_playing:
		sequencer._beat_timer.stop()
		play_current_step(true)
	else:
		update_game_state_from_slot()

		var data = ProgressionManager.get_chord_data(sequencer.current_step)
		if not data.is_empty():
			sequencer._handle_dynamic_scale_override(data)
		else:
			GameManager.clear_scale_override()

		sequencer._clear_all_highlights()
		if data:
			sequencer._visualize_slot_chord(data)

		EventBus.sequencer_step_beat_changed.emit(sequencer.current_step, sequencer.current_beat, sequencer._sub_beat)
		EventBus.bar_changed.emit(sequencer.current_step)

func stop_and_reset() -> void:
	sequencer.is_playing = false
	EventBus.is_sequencer_playing = false
	EventBus.sequencer_playing_changed.emit(false)

	pause_playback()
	reset_position()
	GameManager.clear_scale_override()

func resume_playback() -> void:
	if sequencer._is_paused or sequencer.current_step > 0 or sequencer.current_beat > 0 or sequencer._sub_beat > 0:
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index

		if loop_start != -1 and loop_end != -1:
			if sequencer.current_step < loop_start or sequencer.current_step > loop_end:
				sequencer.current_step = loop_start
				sequencer.current_beat = 0

		play_current_step(true)
	else:
		sequencer.current_step = 0
		sequencer.current_beat = 0

		var loop_start = ProgressionManager.loop_start_index
		if loop_start != -1:
			sequencer.current_step = loop_start

		play_current_step(false)

func pause_playback() -> void:
	sequencer._is_paused = true
	sequencer._beat_timer.stop()

	var data = ProgressionManager.get_chord_data(sequencer.current_step)
	if not data.is_empty():
		update_game_state_from_slot()
		sequencer._handle_dynamic_scale_override(data)
	else:
		GameManager.clear_scale_override()

func play_current_step(is_seek: bool = false) -> void:
	sequencer._clear_chord_highlights()
	update_game_state_from_slot()

	var data = ProgressionManager.get_chord_data(sequencer.current_step)
	if not data.is_empty():
		sequencer._handle_dynamic_scale_override(data)

	if not is_seek:
		sequencer.current_beat = 0
		sequencer._sub_beat = 0

	emit_beat()
	sequencer._play_melody_note()

	if sequencer.current_beat == 0:
		sequencer._play_slot_strum()
	elif is_seek:
		sequencer._play_block_chord()

	EventBus.bar_changed.emit(sequencer.current_step)

	var tick_duration := (60.0 / GameManager.bpm) / 2.0
	sequencer._beat_timer.start(tick_duration)
	sequencer._last_beat_time_ms = Time.get_ticks_msec()
	sequencer._last_tick_time_ms = sequencer._last_beat_time_ms

func start_with_count_in(bars: int = 1) -> void:
	if sequencer.is_playing:
		stop_and_reset()

	sequencer.is_playing = true
	EventBus.is_sequencer_playing = true
	EventBus.sequencer_playing_changed.emit(true)

	sequencer._is_counting_in = true
	sequencer._count_in_beats_left = bars * ProgressionManager.beats_per_bar
	sequencer._sub_beat = 0

	var tick_duration := (60.0 / GameManager.bpm) / 2.0
	sequencer._beat_timer.start(tick_duration)
	sequencer._last_tick_time_ms = Time.get_ticks_msec()
	emit_count_in_signal()

func emit_count_in_signal() -> void:
	EventBus.beat_pulsed.emit()
	if AudioEngine:
		AudioEngine.play_metronome(true)

func on_beat_tick() -> void:
	if sequencer._is_counting_in:
		sequencer._last_tick_time_ms = Time.get_ticks_msec()
		sequencer._sub_beat += 1
		if sequencer._sub_beat >= 2:
			sequencer._sub_beat = 0
			sequencer._count_in_beats_left -= 1

			if sequencer._count_in_beats_left <= 0:
				sequencer._is_counting_in = false
				sequencer.current_beat = 0
				sequencer._sub_beat = 0
				play_current_step(false)
			else:
				emit_count_in_signal()
		return

	sequencer._last_tick_time_ms = Time.get_ticks_msec()
	sequencer._sub_beat += 1
	if sequencer._sub_beat >= 2:
		sequencer._sub_beat = 0
		sequencer.current_beat += 1
		sequencer._last_beat_time_ms = Time.get_ticks_msec()

	var slot_beats = ProgressionManager.get_beats_for_slot(sequencer.current_step)

	if sequencer.current_beat >= slot_beats:
		var next_step = sequencer.current_step + 1
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index

		if loop_start != -1 and loop_end != -1:
			if next_step > loop_end:
				next_step = loop_start
			elif sequencer.current_step < loop_start:
				next_step = loop_start
		else:
			next_step = next_step % ProgressionManager.total_slots

		sequencer.current_step = next_step
		sequencer.current_beat = 0
		sequencer._sub_beat = 0
		play_current_step()
	else:
		check_chord_playback_trigger()
		sequencer._play_melody_note()
		EventBus.sequencer_step_beat_changed.emit(sequencer.current_step, sequencer.current_beat, sequencer._sub_beat)

		if sequencer._sub_beat == 0:
			emit_beat()

func emit_beat() -> void:
	var slot_beats = ProgressionManager.get_beats_for_slot(sequencer.current_step)
	EventBus.beat_updated.emit(sequencer.current_beat, slot_beats)
	EventBus.beat_pulsed.emit()
	EventBus.sequencer_step_beat_changed.emit(sequencer.current_step, sequencer.current_beat, sequencer._sub_beat)

func update_game_state_from_slot() -> void:
	var data = ProgressionManager.get_slot(sequencer.current_step)
	if data == null:
		return

	GameManager.current_chord_root = data.root
	GameManager.current_chord_type = data.type

func get_playback_state() -> Dictionary:
	return {
		"is_playing": sequencer.is_playing,
		"step": sequencer.current_step,
		"beat": sequencer.current_beat,
		"sub_beat": sequencer._sub_beat,
		"last_beat_time": sequencer._last_beat_time_ms,
		"last_tick_time": sequencer._last_tick_time_ms,
		"bpm": GameManager.bpm
	}

func check_chord_playback_trigger() -> void:
	var mode = ProgressionManager.playback_mode

	match mode:
		MusicTheory.ChordPlaybackMode.ONCE:
			pass
		MusicTheory.ChordPlaybackMode.BEAT:
			if sequencer._sub_beat == 0 and sequencer.current_beat > 0:
				sequencer._play_block_chord()
		MusicTheory.ChordPlaybackMode.HALF_BEAT:
			if not (sequencer.current_beat == 0 and sequencer._sub_beat == 0):
				sequencer._play_block_chord()
