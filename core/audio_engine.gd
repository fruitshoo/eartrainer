# audio_engine.gd
# 오디오 엔진 싱글톤 - 기타 음 및 메트로놈 재생
extends Node

# ============================================================
# ENUMS
# ============================================================
enum Tone {
	CLEAN,
	DRIVE
}

# ============================================================
# CONSTANTS - METRONOME
# ============================================================
const METRONOME_ACCENT_PITCH := 1.5
const METRONOME_NORMAL_PITCH := 1.0
const METRONOME_DURATION := 0.03
const METRONOME_FREQUENCY_ACCENT := 1200.0
const METRONOME_FREQUENCY_NORMAL := 800.0

# ============================================================
# CONSTANTS - BUS NAMES
# ============================================================
const BUS_CLEAN := "GuitarClean"
const BUS_DRIVE := "GuitarDrive"

# Input Buses (Volume Control)
const BUS_CHORD := "Chord" # Sends to Clean/Drive
const BUS_MELODY := "Melody" # Sends to Clean/Drive
const BUS_SFX := "SFX" # Sends to Master


# ============================================================
# CONSTANTS - EFFECT PARAMETERS
# ============================================================
# Compressor
const COMP_THRESHOLD_CLEAN := -8.0 # [Jazz] Less aggressive
const COMP_RATIO_CLEAN := 2.5 # [Jazz] Gentle smoothing
const COMP_THRESHOLD_DRIVE := -15.0
const COMP_RATIO_DRIVE := 6.0
const COMP_ATTACK_US := 20000.0 # 20ms
const COMP_RELEASE_MS := 250.0
const COMP_GAIN_CLEAN := 6.0 # [Jazz] Make-up Gain for low volume

# Chorus
const CHORUS_VOICE_COUNT := 2
const CHORUS_DRY := 1.0
const CHORUS_WET := 0.0 # [Jazz] No Chorus (Pure Tone)
const CHORUS_RATE_HZ := 0.5
const CHORUS_DEPTH_MS := 1.5

# Reverb
const REVERB_CLEAN_ROOM := 0.3 # [Jazz] Small Club / Room
const REVERB_CLEAN_DAMPING := 0.7 # [Jazz] Darker reverb tails
const REVERB_CLEAN_WET := 0.15 # [Jazz] Subtle ambience
const REVERB_DRIVE_ROOM := 0.3
const REVERB_DRIVE_WET := 0.2

# Distortion
const DRIVE_AMOUNT := 0.6
const DRIVE_POST_GAIN := -2.0

# ============================================================
# RESOURCES
# ============================================================
var string_samples: Dictionary = {
	0: preload("res://assets/audio/E2.wav"), # Low E (String 6)
	1: preload("res://assets/audio/A2.wav"),
	2: preload("res://assets/audio/D3.wav"),
	3: preload("res://assets/audio/G3.wav"),
	4: preload("res://assets/audio/B3.wav"),
	5: preload("res://assets/audio/E4.wav") # High E (String 1)
}

# Open String MIDI values (for reference/calculation)
# [40, 45, 50, 55, 59, 64]
const OPEN_STRING_MIDI = [40, 45, 50, 55, 59, 64]

# ============================================================
# STATE
# ============================================================
var current_tone: Tone = Tone.CLEAN
var is_metronome_enabled: bool = false # 외부 의존성 제거, 자체 상태 관리

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_setup_audio_buses()
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.beat_updated.connect(_on_beat_updated)

# ============================================================
# INTERNAL - 오디오 버스 및 이펙트 설정
# ============================================================
func _setup_audio_buses() -> void:
	# 1. Effect Buses (Destinations)
	_setup_clean_bus()
	_setup_drive_bus()
	
	# 2. Input Buses (Sources with Volume)
	_setup_routing_bus(BUS_CHORD)
	_setup_routing_bus(BUS_MELODY)
	_setup_routing_bus(BUS_SFX)
	
	# 3. Initial Routing
	_update_bus_routing()

func _setup_routing_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
		
	var idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	# Default send, wil be updated by _update_bus_routing
	AudioServer.set_bus_send(idx, "Master")

func _update_bus_routing() -> void:
	var target_bus = BUS_CLEAN if current_tone == Tone.CLEAN else BUS_DRIVE
	
	# Route Chord & Melody to current Tone Bus
	var chord_idx = AudioServer.get_bus_index(BUS_CHORD)
	if chord_idx != -1:
		AudioServer.set_bus_send(chord_idx, target_bus)
		
	var melody_idx = AudioServer.get_bus_index(BUS_MELODY)
	if melody_idx != -1:
		AudioServer.set_bus_send(melody_idx, target_bus)
		
	# SFX always goes to Master
	var sfx_idx = AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx != -1:
		AudioServer.set_bus_send(sfx_idx, "Master")

func _setup_clean_bus() -> void:
	if AudioServer.get_bus_index(BUS_CLEAN) != -1:
		return

	var idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_CLEAN)
	AudioServer.set_bus_send(idx, "Master")
	
	# 1. Compressor
	var comp = AudioEffectCompressor.new()
	comp.threshold = COMP_THRESHOLD_CLEAN
	comp.ratio = COMP_RATIO_CLEAN
	comp.attack_us = COMP_ATTACK_US
	comp.release_ms = COMP_RELEASE_MS
	comp.gain = COMP_GAIN_CLEAN
	AudioServer.add_bus_effect(idx, comp)

	# 2. Chorus
	var chorus = AudioEffectChorus.new()
	chorus.voice_count = CHORUS_VOICE_COUNT
	chorus.dry = CHORUS_DRY
	chorus.wet = CHORUS_WET
	chorus.set_voice_rate_hz(0, CHORUS_RATE_HZ)
	chorus.set_voice_depth_ms(0, CHORUS_DEPTH_MS)
	AudioServer.add_bus_effect(idx, chorus)
	
	# 3. Reverb
	var reverb = AudioEffectReverb.new()
	reverb.room_size = REVERB_CLEAN_ROOM
	reverb.damping = REVERB_CLEAN_DAMPING
	reverb.spread = 1.0
	reverb.hipass = 0.2
	reverb.dry = 0.7
	reverb.wet = REVERB_CLEAN_WET
	AudioServer.add_bus_effect(idx, reverb)
	
	# 4. EQ (Tone Knob Rolled Off)
	var eq = AudioEffectEQ.new()
	eq.set_band_gain_db(0, 2.0) # Low Boost (Warmth)
	eq.set_band_gain_db(3, -3.0) # Mid scoop/flat
	eq.set_band_gain_db(4, -8.0) # High Mid Cut
	eq.set_band_gain_db(5, -12.0) # High Cut (Dark Jazz Tone)
	AudioServer.add_bus_effect(idx, eq)

func _setup_drive_bus() -> void:
	if AudioServer.get_bus_index(BUS_DRIVE) != -1:
		return

	var idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_DRIVE)
	AudioServer.set_bus_send(idx, "Master")
	
	# 1. Distortion
	var dist = AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = DRIVE_AMOUNT
	dist.post_gain = DRIVE_POST_GAIN
	AudioServer.add_bus_effect(idx, dist)
	
	# 2. Compressor
	var comp = AudioEffectCompressor.new()
	comp.threshold = COMP_THRESHOLD_DRIVE
	comp.ratio = COMP_RATIO_DRIVE
	AudioServer.add_bus_effect(idx, comp)
	
	# 3. EQ
	var eq = AudioEffectEQ.new()
	eq.set_band_gain_db(5, -6.0) # High cut
	AudioServer.add_bus_effect(idx, eq)

	# 4. Reverb
	var reverb = AudioEffectReverb.new()
	reverb.room_size = REVERB_DRIVE_ROOM
	reverb.damping = 0.6
	reverb.dry = 0.8
	reverb.wet = REVERB_DRIVE_WET
	AudioServer.add_bus_effect(idx, reverb)

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_tile_clicked(midi_note: int, string_index: int, _modifiers: Dictionary) -> void:
	play_note(midi_note, string_index)

func _on_beat_updated(beat_index: int, _total_beats: int) -> void:
	if beat_index < 0:
		return
	# 외부 GameManager 의존성 제거됨. 자체 변수 사용.
	if not is_metronome_enabled:
		return
	
	var is_accent := (beat_index == 0)
	play_metronome(is_accent)

# ============================================================
# PUBLIC API - 톤 설정
# ============================================================
func set_tone(mode: Tone) -> void:
	current_tone = mode
	_update_bus_routing() # Route buses to new tone

func toggle_tone() -> void:
	if current_tone == Tone.CLEAN:
		set_tone(Tone.DRIVE)
	else:
		set_tone(Tone.CLEAN)

# ============================================================
# PUBLIC API - 메트로놈 제어
# ============================================================
func set_metronome_enabled(enabled: bool) -> void:
	is_metronome_enabled = enabled

# ============================================================
# PUBLIC API - 기타 음 재생
# ============================================================
# context: "chord" or "melody" (or "default")
func play_note(midi_note: int, string_index: int = -1, context: String = "chord") -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	# Select Sample based on String Index or Pitch
	var selected_string_idx = 0
	
	if string_index != -1:
		# Use specified string
		selected_string_idx = clamp(string_index, 0, 5)
	else:
		# Auto-select best string (prefer lower positions / avoid excessive down-pitching)
		# Iterate from High E (5) down to Low E (0)
		selected_string_idx = 0 # Default to Low E
		for i in range(5, -1, -1):
			if midi_note >= OPEN_STRING_MIDI[i]:
				selected_string_idx = i
				break
	
	player.stream = string_samples.get(selected_string_idx)
	if player.stream == null:
		player.stream = string_samples[0] # Fallback
	
	# Route to correct Input Bus (which then routes to Tone Bus)
	if context == "melody":
		player.bus = BUS_MELODY
	else:
		player.bus = BUS_CHORD
	
	# Calculate Pitch Shift relative to the OPEN STRING of the selected sample
	var base_midi = OPEN_STRING_MIDI[selected_string_idx]
	var pitch_relative = midi_note - base_midi
	player.pitch_scale = pow(2.0, pitch_relative / 12.0)
	
	player.play()
	player.finished.connect(player.queue_free)

func stop_all_notes() -> void:
	var count = 0
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
			count += 1
	print("[AudioEngine] Stopped %d active note players." % count)

# ============================================================
# PUBLIC API - 메트로놈 재생
# ============================================================
func play_metronome(is_accent: bool) -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	# 합성 클릭 사운드 생성
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	player.stream = generator
	
	# 메트로놈은 SFX 버스로
	player.bus = BUS_SFX
	
	var frequency := METRONOME_FREQUENCY_ACCENT if is_accent else METRONOME_FREQUENCY_NORMAL
	var volume := 0.3 if is_accent else 0.2
	
	player.volume_db = linear_to_db(volume)
	player.play()
	
	# 짧은 사인파 생성
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(generator.mix_rate * METRONOME_DURATION)
	
	for i in range(sample_count):
		# 타입을 float으로 명시적으로 지정합니다.
		var t: float = float(i) / generator.mix_rate
		var sample: float = sin(TAU * frequency * t)
		
		# 엔벨로프(envelope)도 타입을 명시합니다.
		var envelope: float = 1.0 - (float(i) / sample_count)
		
		# 소리 데이터 밀어넣기
		playback.push_frame(Vector2(sample * envelope, sample * envelope))
	
	# 재생 완료 후 삭제
	await get_tree().create_timer(METRONOME_DURATION + 0.05).timeout
	player.queue_free()

# ============================================================
# PUBLIC API - SFX (Synthesized)
# ============================================================
func play_sfx(type: String) -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	player.stream = generator
	player.bus = BUS_SFX # SFX는 이펙트 제외
	
	var duration = 0.5
	var freq_start = 880.0
	var freq_end = 880.0
	var vol = 0.5
	
	if type == "correct":
		duration = 0.6
		freq_start = 1046.5 # C6
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
		
		# Simple Synthesis
		var current_freq = lerpf(freq_start, freq_end, progress)
		var sample: float = 0.0
		
		if type == "correct":
			# Bell-like: Sine + Overtone + Exp Decay
			var sine = sin(TAU * current_freq * t)
			var overtone = sin(TAU * (current_freq * 2.0) * t) * 0.5
			sample = (sine + overtone) * 0.5
			var envelope = pow(1.0 - progress, 2.0) # Fast decay
			sample *= envelope
		elif type == "wrong":
			# Softer Thud: Low Sine + Fast Decay (No Sawtooth)
			var sine = sin(TAU * current_freq * t)
			var envelope = pow(1.0 - progress, 3.0)
			sample = sine * envelope
			
		playback.push_frame(Vector2(sample, sample))
		
	await get_tree().create_timer(duration + 0.1).timeout
	if is_instance_valid(player):
		player.queue_free()
