# settings_manager.gd
# 설정 저장 및 복원 싱글톤
extends Node

# ============================================================
# CONSTANTS
# ============================================================
const SAVE_PATH := "user://settings.cfg"

# ============================================================
# PRIVATE
# ============================================================
var _config := ConfigFile.new()

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	load_settings()
	# 설정이 바뀔 때마다 자동 저장
	GameManager.settings_changed.connect(save_settings)

# ============================================================
# PUBLIC API
# ============================================================

## 현재 설정을 파일에 저장
func save_settings() -> void:
	_config.set_value("Music", "key", GameManager.current_key)
	_config.set_value("Music", "mode", GameManager.current_mode)
	_config.set_value("Music", "notation", GameManager.current_notation)
	_config.set_value("Display", "show_hints", GameManager.show_hints)
	_config.set_value("Display", "focus_range", GameManager.focus_range)
	_config.save(SAVE_PATH)

## 파일에서 설정 불러오기
func load_settings() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK:
		return # 파일 없으면 기본값 사용
	
	GameManager.current_key = _config.get_value("Music", "key", 0)
	GameManager.current_mode = _config.get_value("Music", "mode", 0)
	GameManager.current_notation = _config.get_value("Music", "notation", 2)
	GameManager.show_hints = _config.get_value("Display", "show_hints", false)
	GameManager.focus_range = _config.get_value("Display", "focus_range", 3)
