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
# VISUAL UPDATE
# ============================================================
func _refresh_visuals() -> void:
	label.text = GameManager.get_note_label(midi_note)
	
	if not GameManager.show_hints:
		label.visible = false
		_apply_glow(Color(0.1, 0.1, 0.1), 0.0)
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

## 외부에서 호출 가능한 시각 업데이트 (시퀀서용)
func apply_visual_tier(color: Color, energy: float) -> void:
	_apply_glow(color, energy)

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
	# 캐릭터 이동
	if GameManager.current_player:
		GameManager.current_player.jump_to(global_position)
		GameManager.player_fret = fret_index
	
	# 음 재생
	AudioEngine.play_note(midi_note)
	
	# 시퀀서 슬롯 업데이트
	ProgressionManager.set_slot_from_tile(midi_note, string_index, is_shift, is_alt)

# ============================================================
# HELPER METHODS
# ============================================================
func _is_within_focus() -> bool:
	return abs(fret_index - GameManager.player_fret) <= GameManager.focus_range

func _is_key_root() -> bool:
	return (midi_note - GameManager.current_key) % 12 == 0
