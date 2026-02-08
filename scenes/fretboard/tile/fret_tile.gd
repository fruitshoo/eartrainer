# fret_tile.gd
# 지판 타일 (클릭, 시각화, 음 재생)
extends Area3D

# ============================================================
# EXPORTED / METADATA
# ============================================================
var string_index: int = 0
var fret_index: int = 0
var midi_note: int = 0
# Colors are now managed by ThemeManager
# @export_group("Theme Colors") -> Removed in v0.5

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
@onready var mesh: MeshInstance3D = $MeshInstance3D

# ============================================================
# PRIVATE STATE
# ============================================================
var _active_tween: Tween = null
var _label_3d: Label3D = null # [v1.1] ABC Chocolate Style (3D)

# [v0.4] 3-Layer Visual System
# Layer 3: Flash (Transient Hit Feedback) - Highest Priority
var _flash_active: bool = false
var _flash_color: Color = Color.WHITE
var _flash_energy: float = 3.0

# Layer 2: Effect (Melody Playback, Feedback Flash) - High Priority
var _effect_active: bool = false
var _effect_color: Color = Color.TRANSPARENT
var _effect_energy: float = 0.0

# Layer 1: Marker (Question Root, User Selection) - Medium Priority
var _marker_active: bool = false
var _marker_color: Color = Color.TRANSPARENT
var _marker_energy: float = 1.0

# Layer 0: Base (Theory Tiers) - Lowest Priority
# (Calculated dynamically via _get_base_state)

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

func _exit_tree():
	# No manual cleanup needed for Label3D as it's a child node.
	_label_3d = null

func _process(_delta):
	# 3D Labels follow mesh automatically; no projection needed.
	pass

## 타일 초기화 (FretboardManager에서 호출)
func setup(s_idx: int, f_idx: int, note_val: int, _label_container: CanvasLayer = null) -> void:
	string_index = s_idx
	fret_index = f_idx
	midi_note = note_val
	
	# [v1.1] 3D Label3D Setup
	# Parent to MESH so it follows the "press" and "bounce" animations perfectly.
	if _label_3d == null:
		_label_3d = Label3D.new()
		mesh.add_child(_label_3d)
		
		# [Position & Orientation]
		# Half of 0.5 height + small offset
		_label_3d.position = Vector3(0, 0.251, 0)
		_label_3d.rotation_degrees = Vector3(-90, 90, 0) # Lying down & oriented with side markers
		
		# [Style]
		var theme = preload("res://ui/resources/main_theme.tres")
		if theme and theme.default_font:
			_label_3d.font = theme.default_font
			
		_label_3d.font_size = 180 # Large & Chunky
		_label_3d.outline_size = 20
		_label_3d.modulate = Color("#2C222C") # Dark Graphite (Bloom Resistant)
		_label_3d.outline_modulate = Color(1, 1, 1, 0.2) # Soft light outline for depth
		
		# [Rendering]
		_label_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_label_3d.no_depth_test = false # Keep it behind strings/fingers
		_label_3d.alpha_cut = Label3D.ALPHA_CUT_DISABLED
		_label_3d.double_sided = false
	
	_refresh_visuals()

# ============================================================
# VISUAL UPDATE
# ============================================================
func _refresh_visuals() -> void:
	# 0. Update Data Logic
	var is_in_focus := _is_within_focus()
	var tier := GameManager.get_tile_tier(midi_note)
	var is_scale_tone := GameManager.is_in_scale(midi_note)
	
	# 1. Tier & Hierarchy Logic
	var visual_tier := 4 # Default: Avoid (No light)
	
	if tier == 1 and GameManager.highlight_root:
		visual_tier = 1
	elif tier <= 2 and GameManager.highlight_chord:
		visual_tier = 2
	elif is_scale_tone and GameManager.highlight_scale:
		visual_tier = 3
	
	# can_show logic
	# [v0.4] Ensure labels show if Marker/Effect is active (e.g. Question Root),
	# even if base tier is hidden for Anti-Cheat.
	var can_show = is_in_focus and GameManager.show_note_labels and (visual_tier < 4 or _marker_active or _effect_active)
	
	# 2. Update Label (3D)
	if is_instance_valid(_label_3d):
		if can_show:
			_label_3d.text = GameManager.get_note_label(midi_note)
			_label_3d.visible = true
			
			# Dark Tones for high contrast against white/bright highlights
			if midi_note % 12 == 0: # C (Root)
				_label_3d.modulate = Color(0.8, 0.5, 0.0) # Deep Gold/Orange
			else:
				_label_3d.modulate = Color("#2C222C") # Dark Graphite
		else:
			_label_3d.visible = false
	
	# 3. Apply Style (Material) via Layer Resolution
	_update_material_state()
	
func _get_tier_color(tier: int, _p_is_key_root: bool, _is_scale_tone: bool) -> Color:
	var theme = GameManager.current_theme_name
	
	if tier == 1:
		return ThemeManager.get_color(theme, "root")
	elif tier <= 2:
		# Check precise interval for coloring (3rd, 5th, 7th)
		var interval = GameManager.get_current_chord_interval(midi_note)
		if interval == 3 or interval == 4:
			return ThemeManager.get_color(theme, "third")
		elif interval == 10 or interval == 11:
			return ThemeManager.get_color(theme, "seventh")
		else:
			# 5th (7) or others
			return ThemeManager.get_color(theme, "fifth")
	elif tier == 3:
		return ThemeManager.get_color(theme, "scale")
	elif _is_scale_tone:
		return ThemeManager.get_color(theme, "scale")
		
	return ThemeManager.get_color(theme, "avoid")

func _animate_material(color: Color, energy: float) -> void:
	var mat := mesh.get_surface_override_material(0)
	if not mat:
		mat = mesh.get_active_material(0).duplicate()
		mesh.set_surface_override_material(0, mat)
	
	# [v0.7] Toy Look Override Removed
	# Uses standard material glossiness
	
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
# LAYERED VISUAL SYSTEM (v0.4)
# ============================================================

# ============================================================
# LAYERED VISUAL SYSTEM (v0.4)
# ============================================================

# --- INTERFACE ---

## Layer 3: Flash (Transient)
func trigger_flash(color: Color = Color.WHITE, duration: float = 0.15, energy: float = 3.0) -> void:
	_flash_active = true
	_flash_color = color
	_flash_energy = energy
	_refresh_visuals()
	
	# Auto-decay
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(self):
			_flash_active = false
			_refresh_visuals()
	)

## Layer 2: Effect (Melody / Flash)
# Compatibility wrapper for old 'apply_sequencer_highlight'
func apply_sequencer_highlight(color: Variant, energy: float = -1.0) -> void:
	if color == null: color = Color.WHITE
	if energy < 0.0: energy = 1.2 # Reduced from 2.0 to avoid blowout
	
	_effect_active = true
	_effect_color = color
	_effect_energy = energy
	
	_refresh_visuals() # Update material AND label

func clear_sequencer_highlight(_fade_duration: float = 0.2) -> void:
	_effect_active = false
	_refresh_visuals() # Resolve to lower layer

## [v0.3.1] Melody Wrapper (GameManager 호환용)
func apply_melody_highlight() -> void:
	# 보상음악/멜로디 재생 시 밝은 Magenta 색상으로 강조 (User Request: Avoid Cyan/Yellow)
	# Energy reduced to 1.2 to avoid white blowout
	apply_sequencer_highlight(Color.MAGENTA, 0.8) # Reduced from 1.2

func clear_melody_highlight() -> void:
	clear_sequencer_highlight()

## Layer 1: Marker (Quiz Root / Lock)
func set_marker(color: Color, energy: float = 1.0) -> void: # Reduced from 1.5
	_marker_active = true
	_marker_color = color
	_marker_energy = energy
	_refresh_visuals()

func clear_marker() -> void:
	_marker_active = false
	_refresh_visuals()

# --- RESOLUTION LOGIC ---

func _update_material_state() -> void:
	var final_color: Color
	var final_energy: float
	
	if _flash_active:
		# Layer 3: Flash
		final_color = _flash_color
		final_energy = _flash_energy
	elif _effect_active:
		# Layer 2: Effect
		final_color = _effect_color
		final_energy = _effect_energy
	elif _marker_active:
		# Layer 1: Marker
		final_color = _marker_color
		final_energy = _marker_energy
	else:
		# Layer 0: Base
		var state = _get_base_state()
		final_color = state.color
		final_energy = state.energy
		
	_animate_material(final_color, final_energy)

func _get_base_state() -> Dictionary:
	var visual_tier := 4
	var tier := GameManager.get_tile_tier(midi_note)
	var is_scale_tone := GameManager.is_in_scale(midi_note)
	var is_in_focus := _is_within_focus()
	
	# [v0.4.1] Proximity Flashlight Logic
	# If player is near, reveal the note's true tier even if globally hidden.
	if tier == 1 and (GameManager.highlight_root or is_in_focus):
		visual_tier = 1
	elif tier <= 2 and (GameManager.highlight_chord or is_in_focus):
		visual_tier = 2
	elif is_scale_tone and (GameManager.highlight_scale or is_in_focus):
		visual_tier = 3
	
	# Determine Color
	var color = _get_tier_color(visual_tier, false, true)
	if visual_tier == 4:
		color = ThemeManager.get_color(GameManager.current_theme_name, "avoid")
	
	# Determine Energy
	var energy := 0.0
	if visual_tier == 1: energy = root_focus_energy if is_in_focus else 0.3
	elif visual_tier == 2: energy = chord_focus_energy if is_in_focus else 0.2 # [v0.8] Visible globally
	elif visual_tier == 3: energy = scale_focus_energy if is_in_focus else idle_energy
	
	if energy <= 0.0:
		color = ThemeManager.get_color(GameManager.current_theme_name, "avoid")
	
	return {"color": color, "energy": energy}

# ============================================================
# HELPER
# ============================================================
func _is_within_focus() -> bool:
	if not GameManager.current_player: return false
	
	# [v0.4.2] Instant Focus (Logical Distance)
	# Use Logical Fret Distance for instant response (updates on click)
	# instead of waiting for physical travel.
	return abs(GameManager.player_fret - fret_index) <= GameManager.focus_range

# ============================================================
# ANIMATION (JUICE)
# ============================================================
func _animate_press() -> void:
	if _anim_tween and _anim_tween.is_running():
		_anim_tween.kill()
		
	# Mesh만 움직여서 Root(Global Position)는 유지 (플레이어 이동 충돌 방지)
	_anim_tween = create_tween()
	
	# Down (Fast)
	_anim_tween.tween_property(mesh, "position:y", -0.15, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Up (Bounce)
	_anim_tween.tween_property(mesh, "position:y", 0.0, 0.15) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# ============================================================
# INPUT
# ============================================================
func _on_input_event(_camera, event, _event_position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_animate_press() # [New] Juice
			trigger_flash(Color.WHITE, 0.15, 3.0) # [New] Hit Flash (Layer 3)
			EventBus.tile_pressed.emit(midi_note, string_index)
			EventBus.tile_clicked.emit(midi_note, string_index, {
				"position": global_position,
				"fret_index": fret_index
			})
		else:
			EventBus.tile_released.emit(midi_note, string_index)
