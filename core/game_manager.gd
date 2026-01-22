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

var show_hints: bool = false:
	set(value):
		show_hints = value
		settings_changed.emit()

# ============================================================
# STATE VARIABLES - 현재 코드
# ============================================================
var current_chord_root: int = 0:
	set(value):
		current_chord_root = value
		settings_changed.emit()

var current_chord_type: String = "Maj7":
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

var settings_ui_ref: CanvasLayer = null

# ============================================================
# INPUT HANDLING
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_settings()
	
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
	return MusicTheory.get_visual_tier(
		midi_note, current_chord_root, current_chord_type,
		current_key, current_mode
	)

## 음 이름 반환 (노테이션 모드에 따라)
func get_note_label(midi_note: int) -> String:
	var pitch_class := midi_note % 12
	# [수정] := 대신 : String = 을 사용하여 타입을 명시합니다.
	var fixed_name: String = MusicTheory.NOTE_NAMES_CDE[pitch_class]
	
	var relative := (midi_note - current_key) % 12
	if relative < 0: relative += 12
	# [수정] 여기도 타입을 명시합니다.
	var movable_name: String = MusicTheory.NOTE_NAMES_DOREMI[relative]
	
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

func _toggle_settings() -> void:
	if settings_ui_ref:
		settings_ui_ref.visible = !settings_ui_ref.visible

func _apply_diatonic_chord(keycode: int) -> void:
	var data := MusicTheory.get_chord_from_keycode(current_mode, keycode)
	if data.is_empty():
		return
	
	current_chord_root = (current_key + data[0]) % 12
	current_chord_type = data[1]
	current_degree = data[2]
	settings_changed.emit()
