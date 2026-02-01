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

# [v0.4] Difficulty Settings
var show_target_visual: bool = true: # "Easy Mode" vs "Hard Mode"
	set(value):
		show_target_visual = value
		settings_changed.emit()

var is_metronome_enabled: bool = true: # 메트로놈 소리 켜기/끄기
	set(value):
		is_metronome_enabled = value
		if AudioEngine:
			AudioEngine.set_metronome_enabled(value)

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

# [v0.5] Theme Support
var current_theme_name: String = "Pastel":
	set(value):
		if current_theme_name != value:
			current_theme_name = value
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
## 타일의 3-Tier 시각화 계층 반환
func get_tile_tier(midi_note: int) -> int:
	# [DEBUG] 값 추적 - print 주석 해제하여 사용
	# print("get_tile_tier -> Note:%d ChordRoot:%d Type:%s Key:%d Mode:%d" % [midi_note, current_chord_root, current_chord_type, current_key, current_mode])
	return MusicTheory.get_visual_tier(
		midi_note, current_chord_root, current_chord_type,
		current_key, current_mode
	)

## 현재 코드 기준 인터벌 반환 (0=Root, 4=Major3rd, etc.)
func get_current_chord_interval(midi_note: int) -> int:
	var diff = (midi_note - current_chord_root) % 12
	if diff < 0: diff += 12
	return diff

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


	settings_changed.emit()


func _apply_diatonic_chord(keycode: int) -> void:
	var data := MusicTheory.get_chord_from_keycode(current_mode, keycode)
	if data.is_empty():
		return
	
	current_chord_root = (current_key + data[0]) % 12
	current_chord_type = data[1]
	current_degree = data[2]
	settings_changed.emit()

# ============================================================
# PERSISTENCE
# ============================================================
const SAVE_PATH_SETTINGS = "user://game_settings.json"

signal settings_loaded # [New] 초기화 완료 알림
var is_settings_loaded: bool = false # [New] 상태 플래그

# ... (omitted) ...

# Default Preset
var default_preset_name: String = "":
	set(value):
		default_preset_name = value
		settings_changed.emit()

# ... (omitted) ...

func save_settings() -> void:
	var data = {
		"current_key": current_key,
		"current_mode": current_mode,
		"current_notation": current_notation,
		"bpm": bpm,
		"show_note_labels": show_note_labels,
		"highlight_root": highlight_root,
		"highlight_chord": highlight_chord,
		"highlight_scale": highlight_scale,
		"is_metronome_enabled": is_metronome_enabled,
		"focus_range": focus_range,
		"camera_deadzone": camera_deadzone,
		"is_rhythm_mode_enabled": is_rhythm_mode_enabled,
		"default_preset_name": default_preset_name,
		"current_theme_name": current_theme_name # [New]
	}
	
	var file = FileAccess.open(SAVE_PATH_SETTINGS, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[GameManager] Settings saved.")

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH_SETTINGS):
		is_settings_loaded = true # [Fix]
		settings_loaded.emit() # 파일 없어도 로드 완료로 취급
		return
		
	var file = FileAccess.open(SAVE_PATH_SETTINGS, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(text)
		if error == OK:
			var data = json.data
			if data is Dictionary:
				_deserialize_settings(data)
				print("[GameManager] Settings loaded.")
	
	is_settings_loaded = true # [Fix]
	settings_loaded.emit()

func _deserialize_settings(data: Dictionary) -> void:
	current_key = int(data.get("current_key", 0))
	current_mode = int(data.get("current_mode", MusicTheory.ScaleMode.MAJOR)) as MusicTheory.ScaleMode
	current_notation = int(data.get("current_notation", MusicTheory.NotationMode.BOTH)) as MusicTheory.NotationMode
	bpm = int(data.get("bpm", 120))
	
	show_note_labels = data.get("show_note_labels", true)
	highlight_root = data.get("highlight_root", true)
	highlight_chord = data.get("highlight_chord", true)
	highlight_scale = data.get("highlight_scale", true)
	is_metronome_enabled = data.get("is_metronome_enabled", true)
	
	focus_range = int(data.get("focus_range", 3))
	camera_deadzone = float(data.get("camera_deadzone", 4.0))
	is_rhythm_mode_enabled = data.get("is_rhythm_mode_enabled", false)
	default_preset_name = data.get("default_preset_name", "")
	current_theme_name = data.get("current_theme_name", "Default") # [New]

func _ready() -> void:
	call_deferred("load_settings")
	
	# [New] Register MelodyManager
	if not has_node("MelodyManager"):
		var melody_manager = MelodyManager.new()
		melody_manager.name = "MelodyManager"
		add_child(melody_manager)
		
		# Connect MelodyManager visual signals
		melody_manager.visual_note_on.connect(_on_melody_visual_on)
		melody_manager.visual_note_off.connect(_on_melody_visual_off)
	
	# [New] Connect Global EventBus Visuals
	EventBus.visual_note_on.connect(_on_melody_visual_on)
	EventBus.visual_note_off.connect(_on_melody_visual_off)
		
	# [New] Register SongManager
	if not has_node("SongManager"):
		var song_manager = SongManager.new()
		song_manager.name = "SongManager"
		add_child(song_manager)
		
	# [New] Register RiffManager
	if not has_node("RiffManager"):
		var riff_manager = RiffManager.new()
		riff_manager.name = "RiffManager"
		add_child(riff_manager)

func _on_melody_visual_on(midi_note: int, string_idx: int) -> void:
	# 1. Visual Highlight
	var fret = MusicTheory.get_fret_position(midi_note, string_idx)
	var tile = find_tile(string_idx, fret)
	if tile and is_instance_valid(tile):
		if tile.has_method("apply_melody_highlight"):
			tile.apply_melody_highlight()
	
	# 2. Audio Playback
	# [Conflict Fix] Audio should be played by the trigger source (QuizManager, RiffEditor),
	# NOT by the visual event handler. This prevents double triggering.
	# if AudioEngine:
	# 	AudioEngine.play_note(midi_note)

func _on_melody_visual_off(midi_note: int, string_idx: int) -> void:
	if midi_note == -1:
		# Clear ALL visuals (Emergency Stop)
		for tile in get_tree().get_nodes_in_group("fret_tiles"):
			if tile.has_method("clear_melody_highlight"):
				tile.clear_melody_highlight()
		return

	var fret = MusicTheory.get_fret_position(midi_note, string_idx)
	var tile = find_tile(string_idx, fret)
	if tile and is_instance_valid(tile):
		if tile.has_method("clear_melody_highlight"):
			tile.clear_melody_highlight()
