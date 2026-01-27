# audio_engine.gd
# 오디오 엔진 싱글톤 - 기타 음 및 메트로놈 재생
extends Node

# ============================================================
# CONSTANTS
# ============================================================
const METRONOME_ACCENT_PITCH := 1.5 # 1박 강조 피치 배율
const METRONOME_NORMAL_PITCH := 1.0 # 일반 박자 피치
const METRONOME_DURATION := 0.03 # 클릭 지속 시간 (초)
const METRONOME_FREQUENCY_ACCENT := 1200.0 # 1박 주파수 (Hz)
const METRONOME_FREQUENCY_NORMAL := 800.0 # 일반 박자 주파수 (Hz)

const BUS_CLEAN := "GuitarClean"
const BUS_DRIVE := "GuitarDrive"

# ============================================================
# RESOURCES
# ============================================================
var base_sample = preload("res://assets/audio/E2.wav")

# ============================================================
# STATE
# ============================================================
var current_bus_name: String = BUS_CLEAN

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
	# 1. Clean Tone Bus Setup
	if AudioServer.get_bus_index(BUS_CLEAN) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_CLEAN)
		AudioServer.set_bus_send(idx, "Master")
		
		# Chain: Compressor -> Chorus -> Reverb -> EQ(Tone shaping)
		
		# Effect 1: Compressor (단더하고 고른 소리를 위해 맨 앞단에 배치)
		var comp = AudioEffectCompressor.new()
		comp.threshold = -12.0
		comp.ratio = 4.0
		comp.attack_us = 20000.0 # 20ms
		comp.release_ms = 250.0
		AudioServer.add_bus_effect(idx, comp)

		# Effect 2: Chorus (공간감과 색채)
		var chorus = AudioEffectChorus.new()
		chorus.voice_count = 2
		chorus.dry = 0.8
		chorus.wet = 0.3
		chorus.set_voice_rate_hz(0, 0.5) # 천천히 우아하게 흔들림
		chorus.set_voice_depth_ms(0, 1.5) # 과하지 않은 깊이
		AudioServer.add_bus_effect(idx, chorus)
		
		# Effect 3: Reverb (예쁜 잔향 - 필수!)
		var reverb = AudioEffectReverb.new()
		reverb.room_size = 0.5 # 적당한 공간감
		reverb.damping = 0.5 # 따뜻한 잔향
		reverb.spread = 1.0 # 넓은 스테레오 이미지
		reverb.hipass = 0.2 # 저음 잔향 제거 (깔끔하게)
		reverb.dry = 0.7
		reverb.wet = 0.35
		AudioServer.add_bus_effect(idx, reverb)
		
		# Effect 4: EQ (Lo-fi 느낌을 위한 마무리 톤 쉐이핑)
		var eq = AudioEffectEQ.new()
		eq.set_band_gain_db(0, -5.0) # Low cut (Boominess 제거)
		eq.set_band_gain_db(5, -5.0) # High cut (너무 날카롭지 않게, 부드럽게)
		AudioServer.add_bus_effect(idx, eq)

	# 2. Drive Tone Bus Setup
	if AudioServer.get_bus_index(BUS_DRIVE) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_DRIVE)
		AudioServer.set_bus_send(idx, "Master")
		
		# Chain: Distortion -> Compressor -> EQ -> Reverb
		
		# Effect 1: Distortion (오버드라이브)
		var dist = AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
		dist.drive = 0.6 # 과하지 않은 크런치 톤
		dist.post_gain = -2.0
		AudioServer.add_bus_effect(idx, dist)
		
		# Effect 2: Compressor (서스테인 및 레벨 정리)
		var comp = AudioEffectCompressor.new()
		comp.threshold = -15.0
		comp.ratio = 6.0
		AudioServer.add_bus_effect(idx, comp)
		
		# Effect 3: EQ (드라이브 톤의 거친 고음 정리)
		var eq = AudioEffectEQ.new()
		eq.set_band_gain_db(5, -6.0) # High cut
		AudioServer.add_bus_effect(idx, eq)

		# Effect 4: Reverb (드라이브에도 약간의 공간감)
		var reverb = AudioEffectReverb.new()
		reverb.room_size = 0.3
		reverb.damping = 0.6
		reverb.dry = 0.8
		reverb.wet = 0.2
		AudioServer.add_bus_effect(idx, reverb)

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_tile_clicked(midi_note: int, _string_index: int, _modifiers: Dictionary) -> void:
	play_note(midi_note)

func _on_beat_updated(beat_index: int, _total_beats: int) -> void:
	if beat_index < 0:
		return # 시퀀서 정지 시
	if not GameManager.is_metronome_enabled:
		return
	
	var is_accent := (beat_index == 0)
	play_metronome(is_accent)

# ============================================================
# PUBLIC API - 톤 설정
# ============================================================
func set_tone_mode(mode: String) -> void:
	match mode.to_lower():
		"clean":
			current_bus_name = BUS_CLEAN
		"drive":
			current_bus_name = BUS_DRIVE
		_:
			push_warning("Unknown tone mode: %s" % mode)

func toggle_tone() -> void:
	if current_bus_name == BUS_CLEAN:
		set_tone_mode("drive")
	else:
		set_tone_mode("clean")

# ============================================================
# PUBLIC API - 기타 음 재생
# ============================================================
func play_note(midi_note: int) -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	player.stream = base_sample
	# 현재 설정된 버스로 출력
	player.bus = current_bus_name
	
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
