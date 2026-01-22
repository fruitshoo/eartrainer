# hud_manager.gd
# HUD 표시 관리 - 재즈 전광판 스타일
extends CanvasLayer

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var key_label: Label = %KeyLabel
@onready var chord_label: Label = %ChordLabel

# ============================================================
# STATE
# ============================================================
var _last_chord_text: String = ""
var _chord_tween: Tween = null

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.settings_changed.connect(_update_display)
	EventBus.beat_pulsed.connect(_on_beat_pulsed)
	_setup_visual_style()
	_update_display()

# ============================================================
# VISUAL SETUP
# ============================================================
func _setup_visual_style() -> void:
	if chord_label:
		# 글로우 효과를 위한 설정
		chord_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		chord_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.6, 0.2, 0.5))
		chord_label.add_theme_constant_override("shadow_offset_x", 2)
		chord_label.add_theme_constant_override("shadow_offset_y", 2)

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
	
	# 코드 표시 (시퀀서 재생 중이면 시퀀서 코드 우선)
	var chord_root: int
	var chord_type: String
	
	if EventBus.is_sequencer_playing:
		chord_root = GameManager.current_chord_root
		chord_type = GameManager.current_chord_type
	else:
		chord_root = GameManager.current_chord_root
		chord_type = GameManager.current_chord_type
	
	var root_name := MusicTheory.NOTE_NAMES_CDE[chord_root % 12]
	var new_text := "%s %s" % [root_name, chord_type]
	
	# 텍스트가 바뀌었으면 애니메이션 실행
	if new_text != _last_chord_text:
		chord_label.text = new_text
		_animate_chord_change()
		_last_chord_text = new_text

# ============================================================
# ANIMATIONS
# ============================================================

## 코드 변경 시 살짝 커졌다 돌아오는 효과
func _animate_chord_change() -> void:
	if _chord_tween and _chord_tween.is_running():
		_chord_tween.kill()
	
	_chord_tween = create_tween()
	_chord_tween.tween_property(chord_label, "scale", Vector2(1.15, 1.15), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chord_tween.tween_property(chord_label, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 비트 펄스 효과
func _on_beat_pulsed() -> void:
	if not chord_label:
		return
	
	var pulse_tween := create_tween()
	pulse_tween.tween_property(chord_label, "scale", Vector2(1.05, 1.05), 0.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(chord_label, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
