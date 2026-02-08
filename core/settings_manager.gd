# settings_manager.gd
# 설정 저장 및 복원 싱글톤
extends Node

# ============================================================
# CONSTANTS
# ============================================================
const SAVE_PATH := "user://settings.cfg"
const DEFAULT_STRING := 1 # 기본 시작 줄 (4번줄, 인덱스 2)
const DEFAULT_FRET := 5 # 기본 시작 프렛

# ============================================================
# PRIVATE
# ============================================================
var _config := ConfigFile.new()

# 마지막 플레이어 위치 (저장용)
var last_string: int = DEFAULT_STRING
var last_fret: int = DEFAULT_FRET

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	load_settings()
	# 설정이 바뀔 때마다 자동 저장
	GameManager.settings_changed.connect(save_settings)
	# 플레이어 이동 시 위치 업데이트
	GameManager.player_moved.connect(_on_player_moved)

# ============================================================
# PUBLIC API
# ============================================================

## 현재 설정을 파일에 저장
func save_settings() -> void:
	_config.set_value("Music", "key", GameManager.current_key)
	_config.set_value("Music", "mode", int(GameManager.current_mode))
	_config.set_value("Music", "notation_mode", int(GameManager.current_notation_mode))
	
	# [New] Visual Settings
	_config.set_value("Display", "show_note_labels", GameManager.show_note_labels)
	_config.set_value("Display", "highlight_root", GameManager.highlight_root)
	_config.set_value("Display", "highlight_chord", GameManager.highlight_chord)
	_config.set_value("Display", "highlight_scale", GameManager.highlight_scale)
	
	_config.set_value("Display", "focus_range", GameManager.focus_range)
	_config.set_value("Audio", "bpm", GameManager.bpm)
	_config.set_value("Audio", "metronome_enabled", GameManager.is_metronome_enabled)
	_config.set_value("Audio", "rhythm_mode", GameManager.is_rhythm_mode_enabled)
	_config.set_value("Display", "camera_deadzone", GameManager.camera_deadzone)
	
	_config.set_value("Player", "last_string", last_string)
	_config.set_value("Player", "last_fret", last_fret)
	_config.save(SAVE_PATH)

## 파일에서 설정 불러오기
func load_settings() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK:
		return # 파일 없으면 기본값 사용
	
	GameManager.current_key = _config.get_value("Music", "key", 0)
	var mode_int: int = _config.get_value("Music", "mode", 0)
	GameManager.current_mode = mode_int as MusicTheory.ScaleMode
	GameManager.current_notation_mode = _config.get_value("Music", "notation_mode", GameManager.NotationMode.CDE) as GameManager.NotationMode
	
	# Migrate old "notation" key or boolean keys if present
	if _config.has_section_key("Music", "notation"):
		var old_val = _config.get_value("Music", "notation")
		if old_val is int:
			match old_val:
				0: GameManager.current_notation_mode = GameManager.NotationMode.CDE
				1: GameManager.current_notation_mode = GameManager.NotationMode.DOREMI
				2: GameManager.current_notation_mode = GameManager.NotationMode.CDE # Fallback
	elif _config.has_section_key("Music", "show_cde"):
		if _config.get_value("Music", "show_degree", false):
			GameManager.current_notation_mode = GameManager.NotationMode.DEGREE
		elif _config.get_value("Music", "show_doremi", false):
			GameManager.current_notation_mode = GameManager.NotationMode.DOREMI
		else:
			GameManager.current_notation_mode = GameManager.NotationMode.CDE
	
	# [New] Visual Settings
	GameManager.show_note_labels = _config.get_value("Display", "show_note_labels", true)
	GameManager.highlight_root = _config.get_value("Display", "highlight_root", true)
	GameManager.highlight_chord = _config.get_value("Display", "highlight_chord", true)
	GameManager.highlight_scale = _config.get_value("Display", "highlight_scale", true)
	
	GameManager.focus_range = _config.get_value("Display", "focus_range", 3)
	GameManager.bpm = _config.get_value("Audio", "bpm", 120)
	GameManager.is_metronome_enabled = _config.get_value("Audio", "metronome_enabled", true)
	GameManager.is_rhythm_mode_enabled = _config.get_value("Audio", "rhythm_mode", false)
	GameManager.camera_deadzone = _config.get_value("Display", "camera_deadzone", 4.0)
	
	last_string = _config.get_value("Player", "last_string", DEFAULT_STRING)
	last_fret = _config.get_value("Player", "last_fret", DEFAULT_FRET)

## 설정 파일 삭제 및 MAJOR 기본값으로 초기화
func reset_to_defaults() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("settings.cfg"):
		dir.remove("settings.cfg")
	
	# GameManager를 기본값으로 리셋
	GameManager.current_key = 0 # C
	GameManager.current_mode = MusicTheory.ScaleMode.MAJOR
	GameManager.current_notation_mode = GameManager.NotationMode.CDE
	
	GameManager.show_note_labels = true
	GameManager.highlight_root = true
	GameManager.highlight_chord = true
	GameManager.highlight_scale = true
	
	GameManager.focus_range = 3
	GameManager.bpm = 120
	GameManager.is_metronome_enabled = true
	GameManager.is_rhythm_mode_enabled = false

	last_string = DEFAULT_STRING
	last_fret = DEFAULT_FRET
	print("[SettingsManager] Reset to defaults: C Major, Fret 5")

# ============================================================
# PRIVATE
# ============================================================
func _on_player_moved() -> void:
	last_fret = GameManager.player_fret
	# last_string은 타일 클릭 시점에 업데이트됨 (EventBus 통해)
