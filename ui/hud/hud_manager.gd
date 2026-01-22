# hud_manager.gd
# HUD 표시 관리 (키, 모드, 현재 코드)
extends CanvasLayer

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var key_label: Label = %KeyLabel
@onready var chord_label: Label = %ChordLabel

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.settings_changed.connect(_update_display)
	_update_display()

# ============================================================
# DISPLAY UPDATE
# ============================================================
func _update_display() -> void:
	if not key_label or not chord_label:
		return
	
	# 키 + 모드 표시
	var key_name := MusicTheory.NOTE_NAMES_CDE[GameManager.current_key % 12]
	var mode_name := "MAJOR" if GameManager.current_mode == MusicTheory.ScaleMode.MAJOR else "MINOR"
	key_label.text = "[ %s %s ]" % [key_name, mode_name]
	
	# 코드 표시
	var chord_root := MusicTheory.NOTE_NAMES_CDE[GameManager.current_chord_root % 12]
	chord_label.text = "%s %s" % [chord_root, GameManager.current_chord_type]
	chord_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
