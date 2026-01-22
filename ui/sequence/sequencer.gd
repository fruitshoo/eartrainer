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
@export var bpm: int = 80
@export var beats_per_bar: int = 4

# ============================================================
# STATE
# ============================================================
var current_step: int = 0
var current_beat: int = 0 # 현재 마디 내 박자 (0-3)
var is_playing: bool = false

# ============================================================
# PRIVATE
# ============================================================
var _bar_timer: Timer
var _beat_timer: Timer
var _highlighted_tiles: Array = []

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	add_to_group("sequencer") # HUD에서 찾을 수 있도록
	
	_bar_timer = Timer.new()
	add_child(_bar_timer)
	_bar_timer.timeout.connect(_on_bar_complete)
	
	_beat_timer = Timer.new()
	add_child(_beat_timer)
	_beat_timer.timeout.connect(_on_beat_tick)

# ============================================================
# PUBLIC API
# ============================================================
func toggle_play() -> void:
	is_playing = !is_playing
	EventBus.is_sequencer_playing = is_playing
	
	if is_playing:
		current_step = 0
		current_beat = 0
		_play_current_bar()
	else:
		_bar_timer.stop()
		_beat_timer.stop()
		_clear_all_highlights()
		EventBus.beat_updated.emit(-1, beats_per_bar) # 정지 시 리셋

# ============================================================
# PLAYBACK
# ============================================================
func _play_current_bar() -> void:
	var beat_duration := 60.0 / bpm
	var bar_duration := beat_duration * beats_per_bar
	
	current_beat = 0
	_clear_all_highlights()
	_apply_slot_to_game()
	bar_started.emit(current_step)
	EventBus.bar_changed.emit(current_step)
	
	# 첫 번째 비트 즉시 발생
	_emit_beat()
	
	# 비트 타이머 시작 (다음 비트부터)
	_beat_timer.start(beat_duration)
	_bar_timer.start(bar_duration)

func _on_beat_tick() -> void:
	current_beat += 1
	if current_beat < beats_per_bar:
		_emit_beat()

func _emit_beat() -> void:
	EventBus.beat_updated.emit(current_beat, beats_per_bar)
	EventBus.beat_pulsed.emit()

func _on_bar_complete() -> void:
	_beat_timer.stop()
	current_step = (current_step + 1) % ProgressionManager.SLOT_COUNT
	_play_current_bar()

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
