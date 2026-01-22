# fret_tile.gd
# 지판 타일 (클릭, 시각화, 음 재생)
extends Area3D

# ============================================================
# EXPORTED / METADATA
# ============================================================
var string_index: int = 0
var fret_index: int = 0
var midi_note: int = 0

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

# ============================================================
# PRIVATE STATE
# ============================================================
var _active_tween: Tween = null

# [v0.3] 시퀀서 오버레이 전용 상태 (기존 로직과 독립)
var _overlay_active: bool = false
var _overlay_tween: Tween = null
var _overlay_color: Color = Color.TRANSPARENT
var _overlay_energy: float = 0.0

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.settings_changed.connect(_refresh_visuals)
	GameManager.player_moved.connect(_refresh_visuals)
	_refresh_visuals()

## 타일 초기화 (FretboardManager에서 호출)
func setup(s: int, f: int, note: int) -> void:
	string_index = s
	fret_index = f
	midi_note = note

# ============================================================
# VISUAL UPDATE (기존 로직 100% 보존)
# ============================================================
func _refresh_visuals() -> void:
	label.text = GameManager.get_note_label(midi_note)
	
	if not GameManager.show_hints:
		label.visible = false
		_apply_glow(Color(0.1, 0.1, 0.1), 0.0)
		_reapply_overlay_if_active()
		return
	
	var is_in_focus := _is_within_focus()
	var is_key_root := _is_key_root()
	var tier := GameManager.get_tile_tier(midi_note)
	var is_scale_tone := GameManager.is_in_scale(midi_note)
	
	if not is_in_focus:
		label.visible = false
		if is_key_root:
			_apply_glow(Color(0.8, 0.6, 0.2), 0.3) # 희미한 북극성
		elif is_scale_tone:
			_apply_glow(Color(0.2, 0.2, 0.2), 0.05) # 가로등
		else:
			_apply_glow(Color(0.05, 0.05, 0.05), 0.0)
		_reapply_overlay_if_active()
		return
	
	# 포커스 영역 내
	label.visible = true
	
	if is_key_root:
		_apply_glow(Color(1.0, 0.8, 0.2), 2.5) # 북극성 (황금)
	elif tier <= 2:
		_apply_glow(Color(0.3, 0.8, 1.0), 1.8) # 코드톤 (하늘색)
	elif is_scale_tone:
		_apply_glow(Color(0.4, 0.4, 0.4), 0.3) # 스케일톤 (회색)
	else:
		label.visible = false
		_apply_glow(Color(0.05, 0.05, 0.05), 0.0) # 어보이드
	
	_reapply_overlay_if_active()

func _apply_glow(color: Color, energy: float) -> void:
	var mat := mesh.get_surface_override_material(0)
	if not mat:
		mat = mesh.get_active_material(0).duplicate()
		mesh.set_surface_override_material(0, mat)
	
	if _active_tween:
		_active_tween.kill()
	
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(mat, "albedo_color", color, 0.2)
	
	if energy > 0:
		mat.emission_enabled = true
		_active_tween.tween_property(mat, "emission", color, 0.2)
		_active_tween.tween_property(mat, "emission_energy_multiplier", energy, 0.2)
	else:
		_active_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.2)

# ============================================================
# SEQUENCER OVERLAY (비파괴적 덧칠 시스템)
# ============================================================

## 시퀀서 하이라이트 적용 (기존 시각화 위에 덮어씌움)
func apply_sequencer_highlight(color: Color, energy: float) -> void:
	_overlay_active = true
	_overlay_color = color
	_overlay_energy = energy
	_apply_overlay(color, energy)

## 시퀀서 하이라이트 해제 → 기존 시각화로 복귀
func clear_sequencer_highlight() -> void:
	_overlay_active = false
	_overlay_color = Color.TRANSPARENT
	_overlay_energy = 0.0
	_refresh_visuals() # 원래 상태로 복귀

## 오버레이 강제 적용 (별도 Tween 사용)
func _apply_overlay(color: Color, energy: float) -> void:
	var mat := mesh.get_surface_override_material(0)
	if not mat:
		mat = mesh.get_active_material(0).duplicate()
		mesh.set_surface_override_material(0, mat)
	
	if _overlay_tween:
		_overlay_tween.kill()
	
	_overlay_tween = create_tween().set_parallel(true)
	_overlay_tween.tween_property(mat, "albedo_color", color, 0.08)
	mat.emission_enabled = true
	_overlay_tween.tween_property(mat, "emission", color, 0.08)
	_overlay_tween.tween_property(mat, "emission_energy_multiplier", energy, 0.08)

## _refresh_visuals 후 오버레이가 활성 상태면 다시 적용
func _reapply_overlay_if_active() -> void:
	if _overlay_active:
		_apply_overlay(_overlay_color, _overlay_energy)

## 외부에서 호출 가능한 시각 업데이트 (레거시 호환)
func apply_visual_tier(color: Color, energy: float) -> void:
	apply_sequencer_highlight(color, energy)

func update_appearance() -> void:
	_refresh_visuals()

# ============================================================
# INPUT HANDLING
# ============================================================
func _input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var is_shift := Input.is_key_pressed(KEY_SHIFT)
		var is_alt := Input.is_key_pressed(KEY_ALT)
		_on_clicked(is_shift, is_alt)

func _on_clicked(is_shift: bool, is_alt: bool) -> void:
	# [v0.3] 모든 직접 호출 제거 → EventBus로 이벤트만 발생
	EventBus.tile_clicked.emit(midi_note, string_index, {
		"shift": is_shift,
		"alt": is_alt,
		"fret_index": fret_index,
		"position": global_position
	})

# ============================================================
# HELPER METHODS
# ============================================================
func _is_within_focus() -> bool:
	return abs(fret_index - GameManager.player_fret) <= GameManager.focus_range

func _is_key_root() -> bool:
	return (midi_note - GameManager.current_key) % 12 == 0
