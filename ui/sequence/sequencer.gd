# sequencer.gd
# 코드 진행 자동 재생 엔진
extends Node

const SEQUENCER_PLAYBACK = preload("res://ui/sequence/sequencer_playback.gd")
const SEQUENCER_VISUALS = preload("res://ui/sequence/sequencer_visuals.gd")

# ============================================================
# SIGNALS
# ============================================================


# ============================================================
# EXPORTS
# ============================================================
# beats_per_bar removed - use ProgressionManager.beats_per_bar instead

# ============================================================
# STATE
# ============================================================
var current_step: int = 0
var current_beat: int = 0 # 현재 마디 내 박자 (0-3)
var is_playing: bool = false
var _is_paused: bool = false # 일시정지 상태 추적
var _last_beat_time_ms: int = 0 # 리듬 판정용 시간 기록
var _last_tick_time_ms: int = 0
var _sub_beat: int = 0 # [New] 0 = On Beat, 1 = Off Beat (Half-beat)
var _is_counting_in: bool = false # [New] 카운트인 상태
var _count_in_beats_left: int = 0

# ============================================================
# CONSTANTS - PLAYBACK & ACCENTS
# ============================================================
const PLAYBACK_STYLE_BLOCK := "block"
const PLAYBACK_STYLE_STRUM := "strum"

const STRUM_DELAY_SEC := 0.05

const ACCENT_VOLUME_STRONG := 1.0 # Beat 1
const ACCENT_VOLUME_NORMAL := 0.8 # Beat 2, 3, 4...
const ACCENT_VOLUME_WEAK := 0.6 # Half-beats

# ============================================================
# PRIVATE
# ============================================================
var _beat_timer: Timer
var _highlighted_chord_tiles: Array = []
var _active_melody_tile: Node = null
var _playback_helper: SequencerPlayback
var _visual_helper: SequencerVisuals

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_playback_helper = SEQUENCER_PLAYBACK.new(self)
	_visual_helper = SEQUENCER_VISUALS.new(self)
	_beat_timer = Timer.new()
	add_child(_beat_timer)
	_beat_timer.timeout.connect(_on_beat_tick)
	
	EventBus.request_toggle_playback.connect(toggle_play)
	EventBus.request_stop_playback.connect(stop_and_reset)

# ============================================================
# PUBLIC API
# ============================================================
## 재생/일시정지 토글 (위치 유지)
func toggle_play() -> void:
	_playback_helper.toggle_play()

## 위치를 초기화 (정지 상태에서 사용)
func reset_position() -> void:
	_playback_helper.reset_position()
	
## [New] 특정 위치로 이동 (재생 중이면 즉시 이동)
func seek(step: int, beat: int, sub_beat: int = 0) -> void:
	_playback_helper.seek(step, beat, sub_beat)

## 완전 정지 및 리셋 (Stop 버튼용)
func stop_and_reset() -> void:
	_playback_helper.stop_and_reset()

## [New] 코드 미리보기 (하이라이트만)
func preview_chord(root: int, type: String, string_idx: int) -> void:
	_visual_helper.preview_chord(root, type, string_idx)

## [New] 미리보기 해제
func clear_preview() -> void:
	_visual_helper.clear_preview()


# ============================================================
# PLAYBACK CONTROL
# ============================================================
# ============================================================
# PLAYBACK CONTROL
# ============================================================
func _resume_playback() -> void:
	_playback_helper.resume_playback()

func _pause_playback() -> void:
	_playback_helper.pause_playback()

# ============================================================
# PLAYBACK LOGIC
# ============================================================
# ============================================================
# PLAYBACK LOGIC
# ============================================================
func _play_current_step(is_seek: bool = false) -> void:
	_playback_helper.play_current_step(is_seek)

## [New] 카운트인과 함께 재생 시작
func start_with_count_in(bars: int = 1) -> void:
	_playback_helper.start_with_count_in(bars)

func _emit_count_in_signal() -> void:
	_playback_helper.emit_count_in_signal()

func _on_beat_tick() -> void:
	_playback_helper.on_beat_tick()

func _emit_beat() -> void:
	_playback_helper.emit_beat()

func _update_game_state_from_slot() -> void:
	_playback_helper.update_game_state_from_slot()

# ============================================================
# UNIFIED PLAYBACK LOGIC
# ============================================================
# ============================================================
# TIME & STATE ACCESS (For MelodyManager)
# ============================================================
func get_playback_state() -> Dictionary:
	return _playback_helper.get_playback_state()

func _play_slot_strum() -> void:
	_visual_helper.play_slot_strum()

func _play_block_chord() -> void:
	_visual_helper.play_block_chord()
		
## 통합된 코드 재생 함수 (블록/스트럼/파워코드 자동 처리)
func _play_chord_internal(data: Dictionary, requested_style: String) -> void:
	await _visual_helper.play_chord_internal(data, requested_style)

func _get_current_accent_volume() -> float:
	return _visual_helper.get_current_accent_volume()
## [New] 코드 모양 시각화 (오디오 없음)
func _visualize_slot_chord(data: Dictionary) -> void:
	_visual_helper.visualize_slot_chord(data)

# ============================================================
# HIGHLIGHT MANAGEMENT
# ============================================================
func _clear_all_highlights() -> void:
	_visual_helper.clear_all_highlights()

func _clear_chord_highlights() -> void:
	_visual_helper.clear_chord_highlights()

func _clear_melody_highlights() -> void:
	_visual_helper.clear_melody_highlights()

func _check_chord_playback_trigger() -> void:
	_playback_helper.check_chord_playback_trigger()

# [New] Helper for Dynamic Scale Override
func _handle_dynamic_scale_override(data: Dictionary) -> void:
	_visual_helper.handle_dynamic_scale_override(data)

# [New] Melody Playback Logic
func _play_melody_note() -> void:
	_visual_helper.play_melody_note()
