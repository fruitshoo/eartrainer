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
var _is_animating: bool = false

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.settings_changed.connect(_update_display)
	EventBus.beat_pulsed.connect(_on_beat_pulsed)
	EventBus.bar_changed.connect(_on_bar_changed)
	_setup_visual_style()
	call_deferred("_delayed_setup")

func _delayed_setup() -> void:
	await get_tree().process_frame
	_update_display()

# ============================================================
# VISUAL SETUP
# ============================================================
func _setup_visual_style() -> void:
	if chord_label:
		# 피벗을 중앙으로 설정 (애니메이션이 중앙에서 커지도록)
		chord_label.pivot_offset = chord_label.size / 2.0
		
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
	
	# 코드 표시
	var chord_root: int = GameManager.current_chord_root
	var chord_type: String = GameManager.current_chord_type
	
	# 시퀀서 재생 중이면 현재 슬롯 데이터 사용
	if EventBus.is_sequencer_playing:
		var sequencer = get_tree().get_first_node_in_group("sequencer")
		if sequencer:
			var slot_data = ProgressionManager.get_slot(sequencer.current_step)
			if slot_data:
				chord_root = slot_data.root
				chord_type = slot_data.type
	
	# 빈 코드 처리
	if chord_type.is_empty():
		_fade_out_chord_label()
		return
	else:
		chord_label.modulate.a = 1.0
	
	var root_name := MusicTheory.NOTE_NAMES_CDE[chord_root % 12]
	var new_text := "%s %s" % [root_name, chord_type]
	
	# 피벗 재계산 (텍스트 변경 시 size가 바뀔 수 있음)
	chord_label.pivot_offset = chord_label.size / 2.0
	
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
	
	_is_animating = true
	_chord_tween = create_tween()
	_chord_tween.tween_property(chord_label, "scale", Vector2(1.15, 1.15), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chord_tween.tween_property(chord_label, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_chord_tween.finished.connect(func(): _is_animating = false)

## 비트 펄스 효과 (시퀀서 재생 중 + 애니메이션 안 할 때만)
func _on_beat_pulsed() -> void:
	if not chord_label or not EventBus.is_sequencer_playing or _is_animating:
		return
	
	var pulse_tween := create_tween()
	pulse_tween.tween_property(chord_label, "scale", Vector2(1.05, 1.05), 0.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(chord_label, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## 마디 변경 시 디스플레이 업데이트
func _on_bar_changed(_slot_index: int) -> void:
	_update_display()

## 빈 코드일 때 페이드아웃
func _fade_out_chord_label() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(chord_label, "modulate:a", 0.3, 0.2)
