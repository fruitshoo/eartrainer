# game_manager.gd
# 게임 상태 및 설정 관리 싱글톤
extends Node

const GAME_MANAGER_THEORY = preload("res://core/game_manager_theory.gd")
const GAME_MANAGER_TILES = preload("res://core/game_manager_tiles.gd")
const GAME_MANAGER_SETTINGS = preload("res://core/game_manager_settings.gd")

# ============================================================
# SIGNALS
# ============================================================
signal settings_changed
signal player_moved
signal ui_scale_changed(value: float)

enum NotationMode {CDE, DOREMI, DEGREE}

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

# [New] Scale Override (For Non-Diatonic Visualization)
var override_key: int = -1:
	set(value):
		if override_key != value:
			override_key = value
			settings_changed.emit()

var override_mode: int = -1:
	set(value):
		if override_mode != value:
			override_mode = value
			settings_changed.emit()

var override_use_flats: int = -1:
	set(value):
		if override_use_flats != value:
			override_use_flats = value
			settings_changed.emit()

var current_notation_mode: NotationMode = NotationMode.CDE:
	set(value):
		current_notation_mode = value
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
		settings_changed.emit()

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
var _tile_lookup: Dictionary = {}
var _theory_helper: GameManagerTheory
var _tile_helper: GameManagerTiles
var _settings_helper: GameManagerSettings

# ============================================================
# STATE VARIABLES - 플레이어 & UI
# ============================================================
var current_player: Node3D = null
var fixed_fretboard_view: bool = true:
	set(value):
		if fixed_fretboard_view != value:
			fixed_fretboard_view = value
			settings_changed.emit()

var player_fret: int = 0:
	set(value):
		if player_fret != value:
			player_fret = value
			player_moved.emit()

var player_string: int = 0: # [New] Track player string for focus logic
	set(value):
		if player_string != value:
			player_string = value
			player_moved.emit()

var focus_range: int = 3:
	set(value):
		focus_range = value
		settings_changed.emit()

var string_focus_range: int = 6: # [New] 6=All, 2=Wide, 1=Standard, 0=Single
	set(value):
		string_focus_range = value
		settings_changed.emit()

var camera_deadzone: float = 4.0:
	set(value):
		camera_deadzone = clampf(value, 0.0, 10.0)
		settings_changed.emit()

var ui_scale: float = 1.0:
	set(value):
		var old_scale = ui_scale
		ui_scale = clampf(value, 0.5, 1.2)
		if old_scale != ui_scale:
			ui_scale_changed.emit(ui_scale)
			settings_changed.emit()

var is_rhythm_mode_enabled: bool = false:
	set(value):
		is_rhythm_mode_enabled = value
		settings_changed.emit()

# [v0.5] Theme Support
var current_theme_name: String = "Default":
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
		if event.keycode == KEY_TAB: # [New] Toggle Mode
			_toggle_mode()
		elif event.keycode == KEY_M: # [New] Toggle Metronome
			is_metronome_enabled = !is_metronome_enabled
		elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
			_apply_diatonic_chord(event.keycode)

# ============================================================
# PUBLIC API
# ============================================================

## 스케일 오버라이드 설정 (일시적 변경)
func set_scale_override(key: int, mode: int, use_flats: int = -1) -> void:
	_theory_helper.set_scale_override(key, mode, use_flats)

## 스케일 오버라이드 해제
func clear_scale_override() -> void:
	_theory_helper.clear_scale_override()

## 타일의 3-Tier 시각화 계층 반환
## 타일의 3-Tier 시각화 계층 반환
func get_tile_tier(midi_note: int) -> int:
	return _theory_helper.get_tile_tier(midi_note)

## 현재 코드 기준 인터벌 반환 (0=Root, 4=Major3rd, etc.)
func get_current_chord_interval(midi_note: int) -> int:
	return _theory_helper.get_current_chord_interval(midi_note)

## 음 이름 반환 (노테이션 모드에 따라)
func get_note_label(midi_note: int) -> String:
	return _theory_helper.get_note_label(midi_note)

## 음이 현재 스케일에 포함되는지
func is_in_scale(midi_note: int) -> bool:
	return _theory_helper.is_in_scale(midi_note)

## 특정 줄/프렛의 타일 찾기
func find_tile(string_idx: int, fret_idx: int) -> Node:
	return _tile_helper.find_tile(string_idx, fret_idx)

func register_fret_tile(tile: Node) -> void:
	_tile_helper.register_fret_tile(tile)

func unregister_fret_tile(tile: Node) -> void:
	_tile_helper.unregister_fret_tile(tile)

func _get_tile_key(string_idx: int, fret_idx: int) -> String:
	return _tile_helper.get_tile_key(string_idx, fret_idx)

# ============================================================
# PRIVATE METHODS
# ============================================================
func _toggle_mode() -> void:
	_theory_helper.toggle_mode()


func _apply_diatonic_chord(keycode: int) -> void:
	_theory_helper.apply_diatonic_chord(keycode)

# ============================================================
# PERSISTENCE
# ============================================================
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
	_settings_helper.save_settings()

func load_settings() -> void:
	_settings_helper.load_settings()

func _deserialize_settings(data: Dictionary) -> void:
	_settings_helper.deserialize_settings(data)

func _get_volume_settings() -> Dictionary:
	return _settings_helper.get_volume_settings()

func _get_bus_volume(bus_name: String) -> float:
	return _settings_helper.get_bus_volume(bus_name)

func _apply_volume_settings(settings: Dictionary) -> void:
	_settings_helper.apply_volume_settings(settings)

func _ready() -> void:
	_theory_helper = GAME_MANAGER_THEORY.new(self)
	_tile_helper = GAME_MANAGER_TILES.new(self)
	_settings_helper = GAME_MANAGER_SETTINGS.new(self)
	_settings_helper.setup_runtime_nodes()
	player_string = SettingsManager.last_string
	player_fret = SettingsManager.last_fret

func _on_melody_visual_on(midi_note: int, string_idx: int) -> void:
	_tile_helper.on_melody_visual_on(midi_note, string_idx)

func _on_melody_visual_off(midi_note: int, string_idx: int) -> void:
	_tile_helper.on_melody_visual_off(midi_note, string_idx)
