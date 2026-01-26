# game_manager.gd
# 게임 상태 및 설정 관리 싱글톤
extends Node

# ============================================================
# SIGNALS
# ============================================================
signal settings_changed
signal player_moved

# ============================================================
# STATE VARIABLES - 음악 설정
# ============================================================
var current_key: int = 0: ## 현재 키 (0-11, C=0)
	set(value):
		current_key = value
		current_chord_root = value
		settings_changed.emit()

var current_mode: MusicTheory.ScaleMode = MusicTheory.ScaleMode.MAJOR:
	set(value):
		current_mode = value
		_apply_diatonic_chord(KEY_1) # 모드 변경 시 1도로 리셋

var current_notation: MusicTheory.NotationMode = MusicTheory.NotationMode.BOTH:
	set(value):
		current_notation = value
		settings_changed.emit()

# Visualization Settings
var show_note_labels: bool = true:
	set(value):
		show_note_labels = value
		settings_changed.emit()

var highlight_root: bool = true:
	set(value):
		highlight_root = value
		settings_changed.emit()

var highlight_chord: bool = true:
	set(value):
		highlight_chord = value
		settings_changed.emit()

var highlight_scale: bool = true:
	set(value):
		highlight_scale = value
		settings_changed.emit()

var is_metronome_enabled: bool = true # 메트로놈 소리 켜기/끄기

var bpm: int = 120: # 템포 (BPM)
	set(value):
		bpm = clampi(value, 40, 240)
		settings_changed.emit()

# ============================================================
# STATE VARIABLES - 현재 코드
# ============================================================
var current_chord_root: int = 0:
	set(value):
		current_chord_root = value
		settings_changed.emit()

var current_chord_type: String = "M7":
	set(value):
		current_chord_type = value
		settings_changed.emit()

var current_degree: String = "I" ## 로마 숫자 표기

# ============================================================
# STATE VARIABLES - 플레이어 & UI
# ============================================================
var current_player: Node3D = null

var player_fret: int = 0:
	set(value):
		if player_fret != value:
			player_fret = value
			player_moved.emit()

var focus_range: int = 3:
	set(value):
		focus_range = value
		settings_changed.emit()

var camera_deadzone: float = 4.0:
	set(value):
		camera_deadzone = clampf(value, 0.0, 10.0)
		settings_changed.emit()

var is_rhythm_mode_enabled: bool = false:
	set(value):
		is_rhythm_mode_enabled = value
		settings_changed.emit()

# settings_ui_ref 제거됨


# ============================================================
# INPUT HANDLING
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		EventBus.request_toggle_settings.emit()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			_toggle_mode()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
			_apply_diatonic_chord(event.keycode)

# ============================================================
# PUBLIC API
# ============================================================

## 타일의 3-Tier 시각화 계층 반환
func get_tile_tier(midi_note: int) -> int:
	# [DEBUG] 값 추적 - print 주석 해제하여 사용
	# print("get_tile_tier -> Note:%d ChordRoot:%d Type:%s Key:%d Mode:%d" % [midi_note, current_chord_root, current_chord_type, current_key, current_mode])
	return MusicTheory.get_visual_tier(
		midi_note, current_chord_root, current_chord_type,
		current_key, current_mode
	)

## 음 이름 반환 (노테이션 모드에 따라)
func get_note_label(midi_note: int) -> String:
	var use_flats := MusicTheory.should_use_flats(current_key, current_mode)
	
	# 1. CDE 표기 (Fixed)
	var fixed_name: String = MusicTheory.get_note_name(midi_note, use_flats)
	
	# 2. DoReMi 표기 (Relative)
	var relative := (midi_note - current_key) % 12
	if relative < 0: relative += 12
	var movable_name: String = MusicTheory.get_doremi_name(relative, use_flats)
	
	match current_notation:
		MusicTheory.NotationMode.CDE:
			return fixed_name
		MusicTheory.NotationMode.DOREMI:
			return movable_name
		_:
			return "%s (%s)" % [fixed_name, movable_name]

## 음이 현재 스케일에 포함되는지
func is_in_scale(midi_note: int) -> bool:
	return MusicTheory.is_in_scale(midi_note, current_key, current_mode)

## 특정 줄/프렛의 타일 찾기
func find_tile(string_idx: int, fret_idx: int) -> Node:
	for tile in get_tree().get_nodes_in_group("fret_tiles"):
		if tile.string_index == string_idx and tile.fret_index == fret_idx:
			return tile
	return null

# ============================================================
# PRIVATE METHODS
# ============================================================
func _toggle_mode() -> void:
	if current_mode == MusicTheory.ScaleMode.MAJOR:
		current_mode = MusicTheory.ScaleMode.MINOR
	else:
		current_mode = MusicTheory.ScaleMode.MAJOR


func _apply_diatonic_chord(keycode: int) -> void:
	var data := MusicTheory.get_chord_from_keycode(current_mode, keycode)
	if data.is_empty():
		return
	
	current_chord_root = (current_key + data[0]) % 12
	current_chord_type = data[1]
	current_degree = data[2]
	settings_changed.emit()
