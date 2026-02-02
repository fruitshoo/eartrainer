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
var _last_beat_time_ms: int = 0 # 리듬 판정용 시간 기록
var _is_counting_in: bool = false # [New] 카운트인 상태
var _count_in_beats_left: int = 0

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
	
## [New] 특정 위치로 이동 (재생 중이면 즉시 이동)
func seek(step: int, beat: int) -> void:
	current_step = step
	current_beat = beat
	
	if is_playing:
		# 현재 진행 중인 타이머 리셋하고 즉시 재생
		_beat_timer.stop()
		_play_current_step(true) # true = resume from mid-beat logic
	else:
		# 정지 상태면 위치만 업데이트하고 UI/State 갱신 (Preview Mode)
		_update_game_state_from_slot() # HUD 업데이트
		
		# [Fixed] Fretboard Highlight Update
		_clear_all_highlights()
		var data = ProgressionManager.get_slot(current_step)
		if data:
			_visualize_slot_chord(data)
		
		# [New] Playhead 업데이트 (Preview)
		EventBus.sequencer_step_beat_changed.emit(current_step, current_beat)
		
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
	# var beat_duration := 60.0 / GameManager.bpm # Unused
	# Resume 조건: 일시정지 상태이거나, 사용자가 수동으로 위치를 지정한 경우(Step/Beat != 0)
	if _is_paused or current_step > 0 or current_beat > 0:
		# [New] Loop Check: 만약 현재 위치가 루프 구간 밖이라면, 루프 시작점으로 강제 이동
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index
		
		if loop_start != -1 and loop_end != -1:
			if current_step < loop_start or current_step > loop_end:
				current_step = loop_start
				current_beat = 0
		
		# 현재 위치에서 즉시 재생
		# Seek의 경우 _is_paused가 false일 수 있으므로 여기서 강제로 true 처리하는 셈
		_play_current_step(true)
	else:
		# 완전 초기 시작
		current_step = 0
		current_beat = 0
		
		# [New] Loop Start Check
		var loop_start = ProgressionManager.loop_start_index
		if loop_start != -1:
			current_step = loop_start
			
		_play_current_step(false)

func _pause_playback() -> void:
	_is_paused = true
	_beat_timer.stop()

# ============================================================
# PLAYBACK LOGIC
# ============================================================
# ============================================================
# PLAYBACK LOGIC
# ============================================================
func _play_current_step(is_seek: bool = false) -> void:
	_clear_all_highlights()
	
	# 1. 게임 상태 업데이트
	_update_game_state_from_slot()
	
	# 2. 첫 번째 비트(또는 Seek된 비트) 처리
	# seek가 아니면 0부터 시작
	if not is_seek:
		current_beat = 0
	
	_emit_beat()
	
	# 3. 아르페지오 vs 블록 코드 재생
	# 첫 박자면 아르페지오, 중간 박자면 쾅(Block Chord) 찍어서 컨텍스트 제공
	if current_beat == 0:
		_play_slot_strum()
	elif is_seek:
		_play_block_chord()
	
	# 슬롯 변경 알림
	EventBus.bar_changed.emit(current_step)
	
	# 타이머 시작
	var beat_duration := 60.0 / GameManager.bpm
	_beat_timer.start(beat_duration)
	_last_beat_time_ms = Time.get_ticks_msec() # [New] Rhythm Timing

## [New] 카운트인과 함께 재생 시작
func start_with_count_in(bars: int = 1) -> void:
	if is_playing:
		stop_and_reset()
	
	is_playing = true
	EventBus.is_sequencer_playing = true
	EventBus.sequencer_playing_changed.emit(true)
	
	_is_counting_in = true
	_count_in_beats_left = bars * beats_per_bar
	
	# Start Timer for Count-In
	var beat_duration := 60.0 / GameManager.bpm
	_beat_timer.start(beat_duration)
	
	# Initial Tick (Count 4)
	_emit_count_in_signal()

func _emit_count_in_signal() -> void:
	EventBus.beat_pulsed.emit()
	if AudioEngine:
		AudioEngine.play_metronome(true) # Accent for count-in
	
	# Optional: Visual Feedback via EventBus?
	# print("Count-in: ", _count_in_beats_left)

func _on_beat_tick() -> void:
	current_beat += 1
	_last_beat_time_ms = Time.get_ticks_msec() # [New] Rhythm Timing
	
	# [New] Count-In Logic
	if _is_counting_in:
		_count_in_beats_left -= 1
		if _count_in_beats_left <= 0:
			_is_counting_in = false
			current_beat = 0 # Reset for actual start
			_play_current_step(false) # Start actual playback
		else:
			_emit_count_in_signal()
		return
	
	var slot_beats = ProgressionManager.get_beats_for_slot(current_step)
	
	if current_beat >= slot_beats:
		# 슬롯 종료 -> 다음 슬롯으로
		var next_step = current_step + 1
		
		# [New] Loop Range 처리
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index
		
		if loop_start != -1 and loop_end != -1:
			# 루프 구간이 유효하고, 현재 슬롯이 루프 구간 내에 있을 때
			if next_step > loop_end:
				next_step = loop_start
			elif current_step < loop_start:
				# (혹시라도 루프 바깥에서 시작했으면 루프 시작점으로 진입)
				next_step = loop_start
		else:
			# 기본 전체 루프
			next_step = next_step % ProgressionManager.total_slots
			
		current_step = next_step
		current_beat = 0 # 다음 슬롯의 0번 박자
		_play_current_step()
	else:
		# 슬롯 내 박자 진행
		_emit_beat()

func _emit_beat() -> void:
	# UI에 표시할 "마디 내 현재 박자" 계산 (이전 복잡한 로직 대체 필요)
	# 이제 Slot UI가 직접 박자를 그리므로, Sequencer는 "현재 슬롯의 몇 번째 박자"만 알려주면 됨
	# 하지만 HUD 호환성을 위해 기존 signal도 유지해야 할 수 있음.
	# New Signal: 슬롯 내 박자 업데이트 (SlotButton용 via SequenceUI)
	# EventBus에 beat_progressed(step, beat) 추가 필요
	# 임시로 bar_changed를 재활용하거나 새로 만듬.
	# 기존 HUD용 (4/4박자 기준) 로직은 복잡해짐 (마디 길이가 가변이므로)
	# 일단 기존 signal은 유지하되, 값을 대강 맞춰서 보냄
	EventBus.beat_updated.emit(current_beat, 4) # dummy
	EventBus.beat_pulsed.emit()
	
	# 시퀀서 UI에 직접 전달 (나중에 EventBus로 격상 가능)
	# SequenceUI가 이 signal을 들어야 함.
	# 하지만 Sequencer.gd는 EventBus를 통해 통신하는게 원칙.
	EventBus.sequencer_step_beat_changed.emit(current_step, current_beat)
	# beat_pulsed already emitted above

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
	# (Strum logic...)
	
	for offset in offsets:
		var target_string: int = data.string + offset[0]
		var target_fret: int = root_fret + offset[1]
		
		var tile = GameManager.find_tile(target_string, target_fret)
		if tile and is_instance_valid(tile):
			AudioEngine.play_note(tile.midi_note, tile.string_index)
			tile.apply_sequencer_highlight(null)
			_highlighted_tiles.append(tile)
		
		
		await get_tree().create_timer(0.05).timeout

# ============================================================
# TIME & STATE ACCESS (For MelodyManager)
# ============================================================
func get_playback_state() -> Dictionary:
	return {
		"is_playing": is_playing,
		"step": current_step,
		"beat": current_beat,
		"last_beat_time": _last_beat_time_ms,
		"bpm": GameManager.bpm
	}

# ============================================================
# RHYTHM TRAINING LOGIC
# ============================================================
## 비트 판정 (4분/8분 지원)
func check_rhythm_timing() -> Dictionary:
	if not is_playing:
		return {"valid": false}
		
	var now := Time.get_ticks_msec()
	var elapsed := now - _last_beat_time_ms
	var beat_duration_ms: float = (60.0 / GameManager.bpm) * 1000.0
	
	# 8분음표(반박자) 지원 여부에 따라 간격 결정
	var interval := beat_duration_ms
	# 기본적으로는 4분음표(메트로놈 클릭) 기준으로만 판정 (사용자 편의성)
	var target_interval := interval
	
	# 오차 계산
	var offset: float = fmod(elapsed, target_interval)
	var deviation: float = offset
	if offset > target_interval / 2.0:
		deviation = offset - target_interval
		
	# 판정
	var abs_dev := absf(deviation)
	var rating := ""
	var color := Color.WHITE
	
	if abs_dev < 40.0:
		rating = "Perfect!"
		color = Color.CYAN
	elif abs_dev < 150.0:
		rating = "Early" if deviation < 0 else "Late"
		color = Color.GREEN if abs_dev < 100.0 else Color.YELLOW
	elif abs_dev < 250.0:
		rating = "Too Early" if deviation < 0 else "Too Late"
		color = Color.ORANGE
	else:
		rating = "Miss"
		color = Color.GRAY
		
	return {
		"valid": true,
		"deviation": deviation,
		"rating": rating,
		"color": color,
		"ms_error": int(deviation)
	}
	

## [New] 동시에 모든 음 재생 (중간 재생 시 컨텍스트 제공용)
func _play_block_chord() -> void:
	var data = ProgressionManager.get_slot(current_step)
	if data == null:
		return
		
	# 1. 시각화
	_visualize_slot_chord(data)
	
	# 2. 오디오 재생 (별도 로직)
	var root_fret := MusicTheory.get_fret_position(data.root, data.string)
	var voicing_key := MusicTheory.get_voicing_key(data.string)
	var offsets: Array = MusicTheory.VOICING_SHAPES.get(voicing_key, {}).get(data.type, [[0, 0]])
	
	for offset in offsets:
		var target_string: int = data.string + offset[0]
		var target_fret: int = root_fret + offset[1]
		
		var tile = GameManager.find_tile(target_string, target_fret)
		if tile and is_instance_valid(tile):
			AudioEngine.play_note(tile.midi_note, tile.string_index)
## [New] 코드 모양 시각화 (오디오 없음)
func _visualize_slot_chord(data: Dictionary) -> void:
	var root_fret := MusicTheory.get_fret_position(data.root, data.string)
	var voicing_key := MusicTheory.get_voicing_key(data.string)
	var offsets: Array = MusicTheory.VOICING_SHAPES.get(voicing_key, {}).get(data.type, [[0, 0]])
	
	for offset in offsets:
		var target_string: int = data.string + offset[0]
		var target_fret: int = root_fret + offset[1]
		
		var tile = GameManager.find_tile(target_string, target_fret)
		if tile and is_instance_valid(tile):
			tile.apply_sequencer_highlight(null, 0.5) # 짧게 하이라이트
			_highlighted_tiles.append(tile)

# ============================================================
# HIGHLIGHT MANAGEMENT
# ============================================================
func _clear_all_highlights() -> void:
	for tile in _highlighted_tiles:
		if is_instance_valid(tile):
			tile.clear_sequencer_highlight()
	_highlighted_tiles.clear()
