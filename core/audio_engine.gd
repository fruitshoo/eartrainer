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

# ============================================================
# RESOURCES
# ============================================================
var base_sample = preload("res://assets/audio/E2.wav")

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.beat_updated.connect(_on_beat_updated)

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
# PUBLIC API - 기타 음 재생
# ============================================================
func play_note(midi_note: int) -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	player.stream = base_sample
	
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
	
	var frequency := METRONOME_FREQUENCY_ACCENT if is_accent else METRONOME_FREQUENCY_NORMAL
	var volume := 0.3 if is_accent else 0.2
	
	player.volume_db = linear_to_db(volume)
	player.play()
	
	# 짧은 사인파 생성
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(generator.mix_rate * METRONOME_DURATION)
	
	for i in range(sample_count):
		var t := float(i) / generator.mix_rate
		var sample := sin(TAU * frequency * t)
		# 빠른 페이드 아웃 (엔벨로프)
		var envelope := 1.0 - (float(i) / sample_count)
		playback.push_frame(Vector2(sample * envelope, sample * envelope))
	
	# 재생 완료 후 삭제
	await get_tree().create_timer(METRONOME_DURATION + 0.05).timeout
	player.queue_free()