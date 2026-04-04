class_name AudioEnginePlayback
extends RefCounted


func on_tile_clicked(engine, midi_note: int, string_index: int) -> void:
	play_note(engine, midi_note, string_index)


func on_beat_updated(engine, beat_index: int) -> void:
	if beat_index < 0 or not engine.is_metronome_enabled:
		return
	play_metronome(engine, beat_index == 0)


func set_tone(engine, mode: int) -> void:
	engine.current_tone = mode
	engine._bus_helper.update_bus_routing(engine)


func toggle_tone(engine) -> void:
	if engine.current_tone == engine.Tone.CLEAN:
		set_tone(engine, engine.Tone.DRIVE)
	else:
		set_tone(engine, engine.Tone.CLEAN)


func set_metronome_enabled(engine, enabled: bool) -> void:
	engine.is_metronome_enabled = enabled


func play_note(engine, midi_note: int, string_index: int = -1, context: String = "chord", volume_linear: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	engine.add_child(player)
	player.volume_db = linear_to_db(volume_linear)

	var selected_string_idx: int = 0
	if string_index != -1:
		selected_string_idx = clampi(string_index, 0, 5)
	else:
		for i in range(5, -1, -1):
			if midi_note >= engine.OPEN_STRING_MIDI[i]:
				selected_string_idx = i
				break

	player.stream = engine.string_samples.get(selected_string_idx)
	if player.stream == null:
		player.stream = engine.string_samples[0]

	player.bus = engine.BUS_MELODY if context == "melody" else engine.BUS_CHORD

	var base_midi: int = engine.OPEN_STRING_MIDI[selected_string_idx]
	var pitch_relative: int = midi_note - base_midi
	player.pitch_scale = pow(2.0, pitch_relative / 12.0)

	player.play()
	player.finished.connect(player.queue_free)


func stop_all_notes(engine) -> void:
	var count := 0
	for child in engine.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
			count += 1
	print("[AudioEngine] Stopped %d active note players." % count)


func play_metronome(engine, is_accent: bool) -> void:
	var player := AudioStreamPlayer.new()
	engine.add_child(player)

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	player.stream = generator
	player.bus = engine.BUS_SFX

	var frequency: float = engine.METRONOME_FREQUENCY_ACCENT if is_accent else engine.METRONOME_FREQUENCY_NORMAL
	var volume: float = 0.3 if is_accent else 0.2
	player.volume_db = linear_to_db(volume)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(generator.mix_rate * engine.METRONOME_DURATION)
	for i in range(sample_count):
		var t: float = float(i) / generator.mix_rate
		var sample: float = sin(TAU * frequency * t)
		var envelope: float = 1.0 - (float(i) / sample_count)
		playback.push_frame(Vector2(sample * envelope, sample * envelope))

	await engine.get_tree().create_timer(engine.METRONOME_DURATION + 0.05).timeout
	player.queue_free()


func play_sfx(engine, type: String) -> void:
	var player := AudioStreamPlayer.new()
	engine.add_child(player)

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	player.stream = generator
	player.bus = engine.BUS_SFX

	var duration: float = 0.5
	var freq_start: float = 880.0
	var freq_end: float = 880.0
	var vol: float = 0.5

	if type == "correct":
		duration = 0.6
		freq_start = 1046.5
		freq_end = 1046.5
		vol = 0.4
	elif type == "wrong":
		duration = 0.3
		freq_start = 150.0
		freq_end = 100.0
		vol = 0.4

	player.volume_db = linear_to_db(vol)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(generator.mix_rate * duration)
	for i in range(sample_count):
		var t: float = float(i) / generator.mix_rate
		var progress: float = float(i) / sample_count
		var current_freq := lerpf(freq_start, freq_end, progress)
		var sample: float = 0.0

		if type == "correct":
			var sine := sin(TAU * current_freq * t)
			var overtone := sin(TAU * (current_freq * 2.0) * t) * 0.5
			sample = (sine + overtone) * 0.5
			sample *= pow(1.0 - progress, 2.0)
		elif type == "wrong":
			var low_sine := sin(TAU * current_freq * t)
			sample = low_sine * pow(1.0 - progress, 3.0)

		playback.push_frame(Vector2(sample, sample))

	await engine.get_tree().create_timer(duration + 0.1).timeout
	if is_instance_valid(player):
		player.queue_free()
