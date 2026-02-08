# sequencer.gd
# 코드 진행 자동 재생 엔진
extends Node

# ============================================================
# SIGNALS
# ============================================================


# ============================================================
# EXPORTS
# ============================================================
@export var beats_per_bar: int = 4 # TODO: Remove and use ProgressionManager


# ============================================================
# STATE
# ============================================================
var current_step: int = 0
var current_beat: int = 0 # 현재 마디 내 박자 (0-3)
var is_playing: bool = false
var _is_paused: bool = false # 일시정지 상태 추적
var _last_beat_time_ms: int = 0 # 리듬 판정용 시간 기록
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

## [New] 코드 미리보기 (하이라이트만)
func preview_chord(root: int, type: String, string_idx: int) -> void:
	_clear_all_highlights()
	var data = {"root": root, "type": type, "string": string_idx}
	_visualize_slot_chord(data)

## [New] 미리보기 해제
func clear_preview() -> void:
	_clear_all_highlights()
	# 만약 재생 중이 아니면 현재 슬롯의 원래 코드로 복구
	if not is_playing:
		var data = ProgressionManager.get_slot(current_step)
		if data:
			_visualize_slot_chord(data)


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
		_sub_beat = 0
	
	_emit_beat()
	
	# 3. 아르페지오 vs 블록 코드 재생
	# 첫 박자면 아르페지오, 중간 박자면 쾅(Block Chord) 찍어서 컨텍스트 제공
	if current_beat == 0:
		_play_slot_strum()
	elif is_seek:
		_play_block_chord()
	
	# 슬롯 변경 알림
	EventBus.bar_changed.emit(current_step)
	
	# 타이머 시작 (8분음표 단위로 빠르게 실행)
	var tick_duration := (60.0 / GameManager.bpm) / 2.0
	_beat_timer.start(tick_duration)
	_last_beat_time_ms = Time.get_ticks_msec() # [New] Rhythm Timing

## [New] 카운트인과 함께 재생 시작
func start_with_count_in(bars: int = 1) -> void:
	if is_playing:
		stop_and_reset()
	
	is_playing = true
	EventBus.is_sequencer_playing = true
	EventBus.sequencer_playing_changed.emit(true)
	
	_is_counting_in = true
	_count_in_beats_left = bars * ProgressionManager.beats_per_bar # Use Manager
	_sub_beat = 0
	
	# Start Timer for Count-In (8분음표 단위)
	var tick_duration := (60.0 / GameManager.bpm) / 2.0
	_beat_timer.start(tick_duration)
	
	# Initial Tick (Count 4)
	_emit_count_in_signal()

func _emit_count_in_signal() -> void:
	EventBus.beat_pulsed.emit()
	if AudioEngine:
		AudioEngine.play_metronome(true) # Accent for count-in
	
	# Optional: Visual Feedback via EventBus?
	# print("Count-in: ", _count_in_beats_left)

func _on_beat_tick() -> void:
	# [New] Count-In Logic
	if _is_counting_in:
		_sub_beat += 1
		if _sub_beat >= 2:
			_sub_beat = 0
			_count_in_beats_left -= 1
			
			if _count_in_beats_left <= 0:
				_is_counting_in = false
				current_beat = 0
				_sub_beat = 0
				_play_current_step(false)
			else:
				_emit_count_in_signal()
		return
	
	# 1. Sub-beat increment
	_sub_beat += 1
	if _sub_beat >= 2:
		_sub_beat = 0
		current_beat += 1
		_last_beat_time_ms = Time.get_ticks_msec() # Update timing on full beats
	
	# 2. Get beats from Manager for boundary check
	var slot_beats = ProgressionManager.get_beats_for_slot(current_step)
	
	if current_beat >= slot_beats:
		# 슬롯 종료 -> 다음 슬롯으로
		var next_step = current_step + 1
		
		# [New] Loop Range 처리
		var loop_start = ProgressionManager.loop_start_index
		var loop_end = ProgressionManager.loop_end_index
		
		if loop_start != -1 and loop_end != -1:
			if next_step > loop_end:
				next_step = loop_start
			elif current_step < loop_start:
				next_step = loop_start
		else:
			next_step = next_step % ProgressionManager.total_slots
			
		current_step = next_step
		current_beat = 0
		_sub_beat = 0
		_play_current_step()
	else:
		# Still in the same slot
		# A. Check for Chord Playback Triggers
		_check_chord_playback_trigger()
		
		# B. Emit beat signal (only on full beats)
		if _sub_beat == 0:
			_emit_beat()

func _emit_beat() -> void:
	# UI에 표시할 "마디 내 현재 박자" 계산 (이전 복잡한 로직 대체 필요)
	# 이제 Slot UI가 직접 박자를 그리므로, Sequencer는 "현재 슬롯의 몇 번째 박자"만 알려주면 됨
	# 하지만 HUD 호환성을 위해 기존 signal도 유지해야 할 수 있음.
	var slot_beats = ProgressionManager.get_beats_for_slot(current_step)
	
	# New Signal: 슬롯 내 박자 업데이트 (SlotButton용 via SequenceUI)
	# EventBus에 beat_progressed(step, beat) 추가 필요
	# 임시로 bar_changed를 재활용하거나 새로 만듬.
	# 기존 HUD용 (4/4박자 기준) 로직은 복잡해짐 (마디 길이가 가변이므로)
	# 일단 기존 signal은 유지하되, 값을 대강 맞춰서 보냄
	EventBus.beat_updated.emit(current_beat, slot_beats)
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

# ============================================================
# UNIFIED PLAYBACK LOGIC
# ============================================================
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

func _play_slot_strum() -> void:
	var data = ProgressionManager.get_slot(current_step)
	if data:
		_play_chord_internal(data, PLAYBACK_STYLE_STRUM)

func _play_block_chord() -> void:
	var data = ProgressionManager.get_chord_data(current_step)
	if not data.is_empty():
		_play_chord_internal(data, PLAYBACK_STYLE_BLOCK)
		
## 통합된 코드 재생 함수 (블록/스트럼/파워코드 자동 처리)
func _play_chord_internal(data: Dictionary, requested_style: String) -> void:
	if data.is_empty(): return
	
	var accent_volume := _get_current_accent_volume()
	
	var root_fret := MusicTheory.get_fret_position(data.root, data.string)
	var voicing_key := MusicTheory.get_voicing_key(data.string)
	var offsets: Array = MusicTheory.VOICING_SHAPES.get(voicing_key, {}).get(data.type, [[0, 0]])
	
	# Heuristic: Power Chords are ALWAYS Block Style
	var is_power_chord: bool = (data.type == "5")
	var actual_style = PLAYBACK_STYLE_BLOCK if is_power_chord else requested_style
	
	for offset in offsets:
		var target_string: int = data.string + offset[0]
		var target_fret: int = root_fret + offset[1]
		
		var tile = GameManager.find_tile(target_string, target_fret)
		if tile and is_instance_valid(tile):
			AudioEngine.play_note(tile.midi_note, tile.string_index, "chord", accent_volume)
			tile.apply_sequencer_highlight(null)
			_highlighted_tiles.append(tile)
		
		# Strum Delay applies only if style is STRUM
		if actual_style == PLAYBACK_STYLE_STRUM:
			await get_tree().create_timer(STRUM_DELAY_SEC).timeout

func _get_current_accent_volume() -> float:
	if current_beat == 0 and _sub_beat == 0:
		return ACCENT_VOLUME_STRONG
	elif _sub_beat != 0:
		return ACCENT_VOLUME_WEAK
	else:
		return ACCENT_VOLUME_NORMAL
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

func _check_chord_playback_trigger() -> void:
	var mode = ProgressionManager.playback_mode
	
	match mode:
		MusicTheory.ChordPlaybackMode.ONCE:
			# Chords already handled in _play_current_step when beat 0
			pass
		MusicTheory.ChordPlaybackMode.BEAT:
			# Play on every full beat (except beat 0 which is handled by _play_current_step)
			if _sub_beat == 0 and current_beat > 0:
				_play_block_chord()
		MusicTheory.ChordPlaybackMode.HALF_BEAT:
			# Play on every 8th note tick (except beat 0 sub 0)
			if not (current_beat == 0 and _sub_beat == 0):
				_play_block_chord()
