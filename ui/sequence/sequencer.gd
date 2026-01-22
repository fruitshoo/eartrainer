# sequencer.gd
# 코드 진행 자동 재생 엔진
extends Node

# ============================================================
# SIGNALS
# ============================================================
signal bar_started(slot_index: int)

# ============================================================
# EXPORTS
# ============================================================
@export var beats_per_bar: int = 4

# ============================================================
# STATE
# ============================================================
var current_step: int = 0
var current_beat: int = 0 # 현재 마디 내 박자 (0-3)
var is_playing: bool = false
var _is_paused: bool = false # 일시정지 상태 추적

# ============================================================
# PRIVATE
# ============================================================
var _beat_timer: Timer
var _highlighted_tiles: Array = []

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	add_to_group("sequencer") # HUD에서 찾을 수 있도록
	
	_beat_timer = Timer.new()
	add_child(_beat_timer)
	_beat_timer.timeout.connect(_on_beat_tick)

# ============================================================
# PUBLIC API
# ============================================================
## 재생/일시정지 토글 (위치 유지)
func toggle_play() -> void:
	is_playing = !is_playing
	EventBus.is_sequencer_playing = is_playing
	
	if is_playing:
		_resume_playback()
	else:
		_pause_playback()

## 위치를 초기화 (정지 상태에서 사용)
func reset_position() -> void:
	if is_playing:
		return
		
	current_step = 0
	current_beat = 0
	_is_paused = false
	_clear_all_highlights()
	EventBus.beat_updated.emit(-1, beats_per_bar) # UI 리셋
	EventBus.bar_changed.emit(current_step)

# ============================================================
# PLAYBACK CONTROL
# ============================================================
func _resume_playback() -> void:
	var beat_duration := 60.0 / GameManager.bpm
	
	if not _is_paused:
		# 처음 시작
		current_step = 0
		current_beat = 0
		_play_current_bar()
	else:
		# 일시정지 해제: 현재 상태에서 계속 진행
		if current_beat == 0:
			# 마디 시작점이면 전체 로직 실행
			_play_current_bar()
		else:
			# 마디 중간이면 타이머만 재개 (다음 박자 대기)
			_beat_timer.start(beat_duration)

func _pause_playback() -> void:
	_is_paused = true
	_beat_timer.stop()
	# 하이라이트와 비트 인디케이터는 끄지 않음 (위치 확인용)

# ============================================================
# PLAYBACK LOGIC
# ============================================================
func _play_current_bar() -> void:
	_clear_all_highlights()
	_apply_slot_to_game()
	bar_started.emit(current_step)
	EventBus.bar_changed.emit(current_step)
	
	# 첫 번째 비트(0) 처리
	current_beat = 0
	_emit_beat()
	
	# 타이머 시작
	var beat_duration := 60.0 / GameManager.bpm
	_beat_timer.start(beat_duration)

func _on_beat_tick() -> void:
	current_beat += 1
	
	if current_beat >= beats_per_bar:
		# 마디 끝 -> 다음 마디로
		current_step = (current_step + 1) % ProgressionManager.SLOT_COUNT
		_play_current_bar()
	else:
		# 마디 내 박자 진행
		_emit_beat()

func _apply_slot_to_game() -> void:
	var data = ProgressionManager.get_slot(current_step)
	if data == null:
		return
	
	GameManager.current_chord_root = data.root
	GameManager.current_chord_type = data.type
	_play_strum(data)

func _play_strum(data: Dictionary) -> void:
	var root_fret := MusicTheory.get_fret_position(data.root, data.string)
	var voicing_key := MusicTheory.get_voicing_key(data.string)
	var offsets: Array = MusicTheory.VOICING_SHAPES.get(voicing_key, {}).get(data.type, [[0, 0]])
	
	for offset in offsets:
		var target_string: int = data.string + offset[0]
		var target_fret: int = root_fret + offset[1]
		
		var tile = GameManager.find_tile(target_string, target_fret)
		if tile and is_instance_valid(tile):
			AudioEngine.play_note(tile.midi_note)
			tile.apply_sequencer_highlight(Color(1.0, 0.5, 0.2), 3.0)
			_highlighted_tiles.append(tile)
		
		await get_tree().create_timer(0.05).timeout

# ============================================================
# HIGHLIGHT MANAGEMENT
# ============================================================
func _clear_all_highlights() -> void:
	for tile in _highlighted_tiles:
		if is_instance_valid(tile):
			tile.clear_sequencer_highlight()
	_highlighted_tiles.clear()
