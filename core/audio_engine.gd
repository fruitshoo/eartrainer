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

# ============================================================
# CONSTANTS - EFFECT PARAMETERS
# ============================================================
# Compressor
const COMP_THRESHOLD_CLEAN := -12.0
const COMP_RATIO_CLEAN := 4.0
const COMP_THRESHOLD_DRIVE := -15.0
const COMP_RATIO_DRIVE := 6.0
const COMP_ATTACK_US := 20000.0 # 20ms
const COMP_RELEASE_MS := 250.0

# Chorus
const CHORUS_VOICE_COUNT := 2
const CHORUS_DRY := 0.8
const CHORUS_WET := 0.3
const CHORUS_RATE_HZ := 0.5
const CHORUS_DEPTH_MS := 1.5

# Reverb
const REVERB_CLEAN_ROOM := 0.5
const REVERB_CLEAN_DAMPING := 0.5
const REVERB_CLEAN_WET := 0.35
const REVERB_DRIVE_ROOM := 0.3
const REVERB_DRIVE_WET := 0.2

# Distortion
const DRIVE_AMOUNT := 0.6
const DRIVE_POST_GAIN := -2.0

# ============================================================
# RESOURCES
# ============================================================
var base_sample = preload("res://assets/audio/E2.wav")

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
	_setup_clean_bus()
	_setup_drive_bus()

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
	
	# 4. EQ
	var eq = AudioEffectEQ.new()
	eq.set_band_gain_db(0, -5.0) # Low cut
	eq.set_band_gain_db(5, -5.0) # High cut
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
func _on_tile_clicked(midi_note: int, _string_index: int, _modifiers: Dictionary) -> void:
	play_note(midi_note)

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
func play_note(midi_note: int) -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	player.stream = base_sample
	
	# 현재 설정된 톤에 따라 버스 선택
	match current_tone:
		Tone.CLEAN:
			player.bus = BUS_CLEAN
		Tone.DRIVE:
			player.bus = BUS_DRIVE
	
	# MIDI 번호 차이를 이용해 피치 계산 (E2 = 40)
	var pitch_relative = midi_note - 40
	player.pitch_scale = pow(2.0, pitch_relative / 12.0)
	
	player.play()
	player.finished.connect(player.queue_free)

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
	
	# 메트로놈은 마스터 버스로 직접 출력 (이펙트 영향 X)
	player.bus = "Master"
	
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
