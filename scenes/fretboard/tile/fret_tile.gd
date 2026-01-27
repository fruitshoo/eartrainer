# fret_tile.gd
# 지판 타일 (클릭, 시각화, 음 재생)
extends Area3D

# ============================================================
# EXPORTED / METADATA
# ============================================================
var string_index: int = 0
var fret_index: int = 0
var midi_note: int = 0
@export_group("Theme Colors")
@export var root_color: Color = Color(1.0, 0.8, 0.2)
@export var chord_color: Color = Color(0.3, 0.8, 1.0)
@export var scale_color: Color = Color(0.4, 0.4, 0.4)
@export var avoid_color: Color = Color(0.05, 0.05, 0.05)

@export_group("Focus Settings")
@export var idle_energy: float = 0.05
@export var root_focus_energy: float = 1.0
@export var chord_focus_energy: float = 0.5
@export var scale_focus_energy: float = 0.1

@export_group("Sequencer Settings")
@export var sustain_energy: float = 0.8
@export var attack_energy: float = 2.5
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

# [v0.3] 애니메이션 전용 상태 (충돌 방지)
var _anim_tween: Tween = null

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.settings_changed.connect(_refresh_visuals)
	GameManager.player_moved.connect(_refresh_visuals)
	
	# Handle Input
	input_event.connect(_on_input_event)
	
	_refresh_visuals()

## 타일 초기화 (FretboardManager에서 호출)
## 타일 초기화 (FretboardManager에서 호출)
func setup(s_idx: int, f_idx: int, note_val: int) -> void:
	string_index = s_idx
	fret_index = f_idx
	midi_note = note_val

# ============================================================
# VISUAL UPDATE (기존 로직 100% 보존)
# ============================================================
func _refresh_visuals() -> void:
	label.text = GameManager.get_note_label(midi_note)
	
	var is_in_focus := _is_within_focus()
	var tier := GameManager.get_tile_tier(midi_note)
	var is_scale_tone := GameManager.is_in_scale(midi_note)
	
	# 1. Highlight Logic (Hierarchy with Fallback)
	var visual_tier := 4 # Default: Avoid (No light)
	
	if tier == 1 and GameManager.highlight_root:
		visual_tier = 1
	elif tier <= 2 and GameManager.highlight_chord:
		visual_tier = 2
	elif is_scale_tone and GameManager.highlight_scale:
		visual_tier = 3
	
	# 2. Label Visibility
	# Only show if in focus, setting enabled, AND note is visually active
	label.visible = is_in_focus and GameManager.show_note_labels and (visual_tier < 4)
	
	# 3. Apply Style
	var color := _get_tier_color(visual_tier, false, true) # scale_tone param affects color for tier 3
	var energy := 0.0
	
	if visual_tier == 1:
		energy = root_focus_energy if is_in_focus else 0.3
	elif visual_tier == 2:
		energy = chord_focus_energy if is_in_focus else 0.0
	elif visual_tier == 3:
		energy = scale_focus_energy if is_in_focus else idle_energy
		
	if energy <= 0.0:
		color = avoid_color # Force dark if no energy
		
	_apply_glow(color, energy)
	_reapply_overlay_if_active()
	
func _get_tier_color(tier: int, _p_is_key_root: bool, _is_scale_tone: bool) -> Color:
	if tier == 1:
		return root_color
	elif tier <= 2:
		return chord_color
	elif tier == 3: # Explicit scale tier
		return scale_color
	elif _is_scale_tone: # Fallback for old calls
		return scale_color
	return avoid_color

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
## color가 null이면 현재 타일의 기본 색상을 사용함
## energy가 -1.0(기본값)이면 Sequencer Settings의 attack_energy를 사용함
func apply_sequencer_highlight(color: Variant, energy: float = -1.0) -> void:
	if color == null:
		# 현재 타일 속성에 맞는 색상 자동 선택
		var tier := GameManager.get_tile_tier(midi_note)
		var is_key_root := (midi_note - GameManager.current_key) % 12 == 0
		var is_scale_tone := GameManager.is_in_scale(midi_note)
		color = _get_tier_color(tier, is_key_root, is_scale_tone)
	
	if energy < 0:
		energy = attack_energy
		
	_overlay_active = true
	_overlay_color = color
	_overlay_energy = energy
	_apply_overlay(color, energy)
	_animate_press() # [v0.3] 연주 시 '눌림' 효과 추가

## [v0.3] 코드 모양 미리보기 (Beat 0)
func _show_chord_shape_preview() -> void:
	if not GameManager.show_hints:
		return
		
	# 포커스 범위 내의 코드톤(tier <= 2)만 미리 보기에 표시
	if _is_within_focus():
		var tier := GameManager.get_tile_tier(midi_note)
		if tier <= 2:
			apply_sequencer_highlight(null, sustain_energy)

## 시퀀서 하이라이트 해제 → 기존 시각화로 복귀
func clear_sequencer_highlight() -> void:
	_overlay_active = false
	_overlay_color = Color.TRANSPARENT
	_overlay_energy = 0.0
	_refresh_visuals() # 원래 상태로 복귀

# [New] Melody Ghost Note Implementation
func apply_melody_highlight() -> void:
	# Purple highlight for ghost notes
	var ghost_color = Color(0.8, 0.5, 1.0)
	apply_sequencer_highlight(ghost_color, 2.0)

func clear_melody_highlight() -> void:
	clear_sequencer_highlight()

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
	# [v0.3] 플래시 효과: 강하게 켜졌다가(energy) 은은하게 유지(sustain_energy)
	# 중요: 플래시 후에는 '지속 에너지'를 _overlay_energy로 업데이트하여
	#       _reapply 호출 시 다시 번쩍이지 않고 유지되도록 함
	_overlay_tween.chain().tween_property(mat, "emission_energy_multiplier", sustain_energy, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_overlay_tween.tween_callback(func(): _overlay_energy = sustain_energy)

## _refresh_visuals 후 시퀀서가 재생 중이고 오버레이가 활성이면 다시 적용
func _reapply_overlay_if_active() -> void:
	# 시퀀서가 실제로 재생 중일 때만 오버레이 유지
	if _overlay_active and EventBus.is_sequencer_playing:
		_apply_overlay(_overlay_color, _overlay_energy)

## 외부에서 호출 가능한 시각 업데이트 (레거시 호환)
func apply_visual_tier(color: Color, energy: float) -> void:
	apply_sequencer_highlight(color, energy)

func update_appearance() -> void:
	_refresh_visuals()

# ============================================================
# INPUT HANDLING
# ============================================================
func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Mouse Down
				var modifiers = {
					"shift": event.shift_pressed,
					"alt": event.alt_pressed,
					"ctrl": event.ctrl_pressed,
					"meta": event.meta_pressed,
					"position": global_position, # [Fix] Added for Player movement
					"fret_index": fret_index # [Fix] Added for Player logic
				}
				# Keep existing clicked signal for backward compatibility/click logic (handled by others)
				# But wait, click usually implies down+up.
				# Existing logic treats "pressed" as click.
				
				EventBus.tile_clicked.emit(midi_note, string_index, modifiers)
				EventBus.tile_pressed.emit(midi_note, string_index) # [New]
				
				# Visual Feedback (Press)
				_animate_press()
				
			else:
				# Mouse Up
				EventBus.tile_released.emit(midi_note, string_index) # [New]

func _on_clicked(is_shift: bool, is_alt: bool) -> void:
	# [New] Rhythm Training Check
	if GameManager.is_rhythm_mode_enabled and EventBus.is_sequencer_playing:
		var sequencer = get_tree().get_first_node_in_group("sequencer")
		if sequencer and sequencer.has_method("check_rhythm_timing"):
			var result = sequencer.check_rhythm_timing()
			if result.valid:
				_show_rhythm_feedback(result)

	# [v0.3] 모든 직접 호출 제거 → EventBus로 이벤트만 발생
	EventBus.tile_clicked.emit(midi_note, string_index, {
		"shift": is_shift,
		"alt": is_alt,
		"fret_index": fret_index,
		"position": global_position
	})

## [New] 리듬 판정 피드백 표시 (플로팅 텍스트)
func _show_rhythm_feedback(result: Dictionary) -> void:
	var score_label := Label3D.new()
	add_child(score_label)
	
	score_label.text = result.rating
	score_label.modulate = result.color
	score_label.font_size = 64
	score_label.outline_render_priority = 0
	score_label.outline_size = 4
	score_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	score_label.position = Vector3(0, 0.5, 0)
	score_label.no_depth_test = true # 항상 위에 표시
	
	# Tween Animation: 위로 떠오르며 페이드 아웃
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(score_label, "position:y", 1.5, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(score_label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(score_label.queue_free)

# ============================================================
# HELPER METHODS
# ============================================================
func _is_within_focus() -> bool:
	return abs(fret_index - GameManager.player_fret) <= GameManager.focus_range

func _is_key_root() -> bool:
	return (midi_note - GameManager.current_key) % 12 == 0

## [v0.3] 물리적 눌림 효과 (Press & Pop)
func _animate_press() -> void:
	if _anim_tween:
		_anim_tween.kill()
	
	# Position으로 확실한 깊이감 + Scale로 쫀득함 추가
	_anim_tween = create_tween()
	
	# 1. Press (Down): 빠르고 깊게 (-0.1)
	_anim_tween.tween_property(mesh, "position:y", -0.1, 0.05) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(mesh, "scale", Vector3(0.95, 0.95, 0.95), 0.05) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# 2. Pop (Up): 탄력 있게 복귀 (TRANS_BACK)
	_anim_tween.tween_property(mesh, "position:y", 0.0, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(mesh, "scale", Vector3.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
