# game_manager.gd
extends Node

signal settings_changed
signal player_moved

# MusicTheory의 enum 사용
var current_root_note: int = 0:
	set(value):
		current_root_note = value
		current_chord_root = value
		settings_changed.emit()

var current_scale_mode: MusicTheory.ScaleMode = MusicTheory.ScaleMode.MAJOR:
	set(value):
		current_scale_mode = value
		apply_chord_by_map(KEY_1, false) # 모드 변경 시 해당 모드의 1도로 리셋

var current_notation: MusicTheory.NotationMode = MusicTheory.NotationMode.BOTH:
	set(value):
		current_notation = value
		settings_changed.emit()

var is_hint_visible: bool = false:
	set(value):
		is_hint_visible = value
		settings_changed.emit()

var current_chord_root: int = 0:
	set(value):
		current_chord_root = value
		settings_changed.emit()

var current_chord_type: String = "Maj7":
	set(value):
		current_chord_type = value
		settings_changed.emit()

var current_degree_name: String = "I" # 로마자 표기용 추가

# 캐릭터 및 기타 변수 (기존과 동일)
var current_player: Node3D = null
var player_fret: int = 0:
	set(value):
		if player_fret != value:
			player_fret = value
			player_moved.emit()

var focus_range: int = 3:
	set(value):
		focus_range = value
		# 값이 바뀌면 타일들이 다시 계산하도록 신호를 보냅니다.
		settings_changed.emit()
var settings_ui_ref: CanvasLayer = null

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_settings()
	
	if event is InputEventKey and event.pressed:
		# M키: 모드 전환
		if event.keycode == KEY_M:
			current_scale_mode = MusicTheory.ScaleMode.MINOR if current_scale_mode == MusicTheory.ScaleMode.MAJOR else MusicTheory.ScaleMode.MAJOR
			return

		# 숫자키 1~7: 다이어토닉 & 모달 인터체인지 코드 적용
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			apply_chord_by_map(event.keycode, Input.is_key_pressed(KEY_SHIFT))

func apply_chord_by_map(keycode: int, is_shift: bool):
	var data = MusicTheory.get_chord_data(current_scale_mode, keycode, is_shift)
	if data.is_empty(): return
	
	current_chord_root = (current_root_note + data[0]) % 12
	current_chord_type = data[1]
	current_degree_name = data[2]
	
	settings_changed.emit()

func get_note_tier(midi_note: int) -> int:
	return MusicTheory.get_tier(midi_note, current_chord_root, current_chord_type, current_root_note, current_scale_mode)

func get_movable_do_name(midi_note: int) -> String:
	# 1. 절대음명 (C, C#, D...) - 고정 방식
	var abs_idx = midi_note % 12
	var fixed_name = MusicTheory.CDE_NAMES[abs_idx]
	
	# 2. 상대계이름 (도, 도#, 레...) - 이동도(Movable Do) 방식
	var rel_idx = (midi_note - current_root_note) % 12
	if rel_idx < 0: rel_idx += 12
	var movable_name = MusicTheory.DOREMI_NAMES[rel_idx]
	
	# 3. 설정된 노테이션 모드에 따라 반환
	match current_notation:
		MusicTheory.NotationMode.CDE:
			return fixed_name
		MusicTheory.NotationMode.DOREMI:
			return movable_name
		_:
			# 사용자가 원하는 "D (도)" 형태
			return "%s (%s)" % [fixed_name, movable_name]

func toggle_settings():
	if settings_ui_ref:
		settings_ui_ref.visible = !settings_ui_ref.visible

func is_note_in_scale(midi_note: int) -> bool:
	# 실제 계산은 MusicTheory에 맡기고 결과만 받아옵니다.
	return MusicTheory.is_note_in_scale(midi_note, current_root_note, current_scale_mode)

# 특정 줄과 프렛 번호로 타일을 찾아주는 함수
func get_tile(string_idx: int, fret_idx: int) -> Node:
	# 타일들이 들어있는 Group 이름을 'fret_tiles'라고 설정했다고 가정합니다.
	var tiles = get_tree().get_nodes_in_group("fret_tiles")
	for tile in tiles:
		if tile.string_index == string_idx and tile.fret_index == fret_idx:
			return tile
	return null