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

# ============================================================
# STATE
# ============================================================
var current_step: int = 0
var is_playing: bool = false

# ============================================================
# PRIVATE
# ============================================================
var _timer: Timer

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_on_bar_complete)

# ============================================================
# PUBLIC API
# ============================================================
func toggle_play() -> void:
	is_playing = !is_playing
	if is_playing:
		current_step = 0
		_play_current_bar()
	else:
		_timer.stop()

# ============================================================
# PLAYBACK
# ============================================================
func _play_current_bar() -> void:
	var bar_duration := (60.0 / bpm) * 4.0 # 4박자 = 1마디
	
	_apply_slot_to_game()
	bar_started.emit(current_step)
	_timer.start(bar_duration)

func _on_bar_complete() -> void:
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
		if tile:
			AudioEngine.play_note(tile.midi_note)
			tile.apply_visual_tier(Color(2.0, 2.0, 2.0), 3.0)
			_restore_tile_after_delay(tile)
		
		await get_tree().create_timer(0.05).timeout

func _restore_tile_after_delay(tile: Node) -> void:
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(tile):
		tile.update_appearance()
