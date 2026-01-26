# sequencer.gd
# 코드 진행 자동 재생 엔진
extends Node

# ============================================================
# SIGNALS
# ============================================================


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
	add_to_group("sequencer") # TODO: HUD refactoring 후 제거 가능
	
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
	is_playing = !is_playing
	EventBus.is_sequencer_playing = is_playing
	EventBus.sequencer_playing_changed.emit(is_playing)
	
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

## 완전 정지 및 리셋 (Stop 버튼용)
func stop_and_reset() -> void:
	is_playing = false
	EventBus.is_sequencer_playing = false
	EventBus.sequencer_playing_changed.emit(false)
	
	_pause_playback() # 타이머 정지
	reset_position() # 위치 및 UI 리셋


# ============================================================
# PLAYBACK CONTROL
# ============================================================
# ============================================================
# PLAYBACK CONTROL
# ============================================================
func _resume_playback() -> void:
	var beat_duration := 60.0 / GameManager.bpm
	
	if not _is_paused:
		# 처음 시작
		current_step = 0 # Slot Index
		current_beat = 0 # Beat within current slot
		_play_current_step()
	else:
		# 일시정지 해제
		if current_beat == 0:
			_play_current_step()
		else:
			_beat_timer.start(beat_duration)

func _pause_playback() -> void:
	_is_paused = true
	_beat_timer.stop()

# ============================================================
# PLAYBACK LOGIC
# ============================================================
func _play_current_step() -> void:
	_clear_all_highlights()
	
	# 1. 게임 상태 업데이트
	_update_game_state_from_slot()
	
	# 2. 첫 번째 비트 처리
	current_beat = 0
	_emit_beat()
	
	# 3. 아르페지오 재생
	_play_slot_strum()
	
	# 슬롯 변경 알림 (UI 하이라이트용)
	# EventBus.bar_changed -> 이름을 slot_changed로 바꾸면 좋겠지만 
	# 호환성을 위해 의미만 슬롯 인덱스로 사용
	EventBus.bar_changed.emit(current_step)
	
	# 타이머 시작
	var beat_duration := 60.0 / GameManager.bpm
	_beat_timer.start(beat_duration)

func _on_beat_tick() -> void:
	current_beat += 1
	var density = ProgressionManager.chords_per_bar
	var beats_per_slot = int(beats_per_bar / density)
	
	if current_beat >= beats_per_slot:
		# 슬롯 종료 -> 다음 슬롯으로
		current_step = (current_step + 1) % ProgressionManager.total_slots
		_play_current_step()
	else:
		# 슬롯 내 박자 진행
		_emit_beat()

func _emit_beat() -> void:
	# UI에 표시할 "마디 내 현재 박자" 계산
	# 예: 4/4박자, 2분할 시
	# 슬롯 0 (첫 2박): current_beat 0 -> bar_beat 0
	#                current_beat 1 -> bar_beat 1
	# 슬롯 1 (뒛 2박): current_beat 0 -> bar_beat 2
	#                current_beat 1 -> bar_beat 3
	var density = ProgressionManager.chords_per_bar
	var beats_per_slot = int(beats_per_bar / density)
	
	# 현재 슬롯이 마디의 몇 번째 파트인지 확인
	# 슬롯 인덱스 % density 하면 됨
	# density=1 이면 항상 0
	# density=2 이면 0(앞), 1(뒤)
	var sub_index = current_step % density
	var bar_relative_beat = (sub_index * beats_per_slot) + current_beat
	
	# EventBus에 전달
	EventBus.beat_updated.emit(bar_relative_beat, beats_per_bar)
	EventBus.beat_pulsed.emit()

func _update_game_state_from_slot() -> void:
	var data = ProgressionManager.get_slot(current_step)
	if data == null:
		return
	
	GameManager.current_chord_root = data.root
	GameManager.current_chord_type = data.type

func _play_slot_strum() -> void:
	var data = ProgressionManager.get_slot(current_step)
	if data == null:
		return
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
			tile.apply_sequencer_highlight(null)
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
