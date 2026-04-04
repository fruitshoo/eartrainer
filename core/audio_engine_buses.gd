class_name AudioEngineBuses
extends RefCounted


func setup_audio_buses(engine) -> void:
	_setup_clean_bus(engine)
	_setup_drive_bus(engine)
	_setup_chord_bus(engine)
	_setup_melody_bus(engine)
	_setup_routing_bus(engine, engine.BUS_SFX)
	update_bus_routing(engine)


func _setup_chord_bus(engine) -> void:
	if AudioServer.get_bus_index(engine.BUS_CHORD) != -1:
		return

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, engine.BUS_CHORD)

	var panner := AudioEffectPanner.new()
	panner.pan = -0.2
	AudioServer.add_bus_effect(idx, panner)

	var comp := AudioEffectCompressor.new()
	comp.sidechain = engine.BUS_MELODY
	comp.threshold = -24.0
	comp.ratio = 4.0
	comp.attack_us = 10000.0
	comp.release_ms = 150.0
	AudioServer.add_bus_effect(idx, comp)


func _setup_melody_bus(engine) -> void:
	if AudioServer.get_bus_index(engine.BUS_MELODY) != -1:
		return

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, engine.BUS_MELODY)

	var panner := AudioEffectPanner.new()
	panner.pan = 0.2
	AudioServer.add_bus_effect(idx, panner)


func _setup_routing_bus(engine, bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func update_bus_routing(engine) -> void:
	var target_bus: String = engine.BUS_CLEAN if engine.current_tone == engine.Tone.CLEAN else engine.BUS_DRIVE

	var chord_idx := AudioServer.get_bus_index(engine.BUS_CHORD)
	if chord_idx != -1:
		AudioServer.set_bus_send(chord_idx, target_bus)

	var melody_idx := AudioServer.get_bus_index(engine.BUS_MELODY)
	if melody_idx != -1:
		AudioServer.set_bus_send(melody_idx, target_bus)

	var sfx_idx := AudioServer.get_bus_index(engine.BUS_SFX)
	if sfx_idx != -1:
		AudioServer.set_bus_send(sfx_idx, "Master")


func _setup_clean_bus(engine) -> void:
	if AudioServer.get_bus_index(engine.BUS_CLEAN) != -1:
		return

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, engine.BUS_CLEAN)
	AudioServer.set_bus_send(idx, "Master")

	var comp := AudioEffectCompressor.new()
	comp.threshold = engine.COMP_THRESHOLD_CLEAN
	comp.ratio = engine.COMP_RATIO_CLEAN
	comp.attack_us = engine.COMP_ATTACK_US
	comp.release_ms = engine.COMP_RELEASE_MS
	comp.gain = engine.COMP_GAIN_CLEAN
	AudioServer.add_bus_effect(idx, comp)

	var chorus := AudioEffectChorus.new()
	chorus.voice_count = engine.CHORUS_VOICE_COUNT
	chorus.dry = engine.CHORUS_DRY
	chorus.wet = engine.CHORUS_WET
	chorus.set_voice_rate_hz(0, engine.CHORUS_RATE_HZ)
	chorus.set_voice_depth_ms(0, engine.CHORUS_DEPTH_MS)
	AudioServer.add_bus_effect(idx, chorus)

	var reverb := AudioEffectReverb.new()
	reverb.room_size = engine.REVERB_CLEAN_ROOM
	reverb.damping = engine.REVERB_CLEAN_DAMPING
	reverb.spread = 1.0
	reverb.hipass = 0.2
	reverb.dry = 0.7
	reverb.wet = engine.REVERB_CLEAN_WET
	AudioServer.add_bus_effect(idx, reverb)

	var eq := AudioEffectEQ.new()
	eq.set_band_gain_db(0, 2.0)
	eq.set_band_gain_db(3, -3.0)
	eq.set_band_gain_db(4, -8.0)
	eq.set_band_gain_db(5, -12.0)
	AudioServer.add_bus_effect(idx, eq)


func _setup_drive_bus(engine) -> void:
	if AudioServer.get_bus_index(engine.BUS_DRIVE) != -1:
		return

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, engine.BUS_DRIVE)
	AudioServer.set_bus_send(idx, "Master")

	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = engine.DRIVE_AMOUNT
	dist.post_gain = engine.DRIVE_POST_GAIN
	AudioServer.add_bus_effect(idx, dist)

	var comp := AudioEffectCompressor.new()
	comp.threshold = engine.COMP_THRESHOLD_DRIVE
	comp.ratio = engine.COMP_RATIO_DRIVE
	AudioServer.add_bus_effect(idx, comp)

	var eq := AudioEffectEQ.new()
	eq.set_band_gain_db(5, -6.0)
	AudioServer.add_bus_effect(idx, eq)

	var reverb := AudioEffectReverb.new()
	reverb.room_size = engine.REVERB_DRIVE_ROOM
	reverb.damping = 0.6
	reverb.dry = 0.8
	reverb.wet = engine.REVERB_DRIVE_WET
	AudioServer.add_bus_effect(idx, reverb)
