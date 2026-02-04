extends Node3D

@onready var visual = $Visual
@onready var landing_particles: GPUParticles3D = $LandingParticles

# ============================================================
# CONSTANTS
# ============================================================
const MOVE_DURATION := 0.2 # 빠른 이동 애니메이션
const JUMP_HEIGHT := 1.5 # 점프 높이
const DEBOUNCE_TIME := 0.05 # 입력 디바운싱 (30ms)
const LAND_Y := 0.26 # [Fix] Tile Height(0.5)/2 + Padding. Fixes sinking.

# ============================================================
# STATE
# ============================================================
var _horizontal_tween: Tween = null
var _vertical_tween: Tween = null
var _last_click_time: float = 0.0

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.current_player = self
	EventBus.tile_clicked.connect(_on_tile_clicked)
	call_deferred("_initialize_position")

func _initialize_position() -> void:
	await get_tree().process_frame
	
	var target_tile = GameManager.find_tile(
		SettingsManager.last_string,
		SettingsManager.last_fret
	)
	if target_tile:
		global_position = target_tile.global_position
		global_position.y = LAND_Y # [Fix] Apply offset
		GameManager.player_fret = SettingsManager.last_fret
	else:
		GameManager.player_fret = SettingsManager.DEFAULT_FRET
		global_position.y = LAND_Y

# ============================================================
# INPUT HANDLING
# ============================================================
func _on_tile_clicked(_midi_note: int, string_index: int, modifiers: Dictionary) -> void:
	# 디바운싱 체크
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_click_time < DEBOUNCE_TIME:
		return
	_last_click_time = current_time
	
	var target_pos: Vector3 = modifiers.get("position", global_position)
	var fret_index: int = modifiers.get("fret_index", 0)
	
	jump_to(target_pos)
	GameManager.player_fret = fret_index # 즉시 신호 발생 → 하이라이트 업데이트
	SettingsManager.last_string = string_index

# ============================================================
# MOVEMENT
# ============================================================
func jump_to(target_pos: Vector3) -> void:
	# 기존 트윈 강제 종료 → 즉시 방향 전환 가능
	if _horizontal_tween and _horizontal_tween.is_running():
		_horizontal_tween.kill()
	if _vertical_tween and _vertical_tween.is_running():
		_vertical_tween.kill()
	
	# 수평 이동
	_horizontal_tween = create_tween().set_parallel(true)
	_horizontal_tween.tween_property(self, "global_position:x", target_pos.x, MOVE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_horizontal_tween.tween_property(self, "global_position:z", target_pos.z, MOVE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 수직 이동 (올라갔다 내려오기)
	_vertical_tween = create_tween()
	# Jump height based on CURRENT Y or LAND_Y? Absolute height.
	var peak_height = JUMP_HEIGHT
	# Use target Y (which includes LAND_Y/Offset from caller or we assume caller passes raw pos?)
	# Caller (on_tile_clicked) passes target_pos from tile.global_position.
	# We should enforce LAND_Y here too if target_pos.y is 0.
	var landing_y = target_pos.y + LAND_Y # Assume target_pos is tile origin (y=0)
	
	_vertical_tween.tween_property(self, "global_position:y", peak_height, MOVE_DURATION * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_vertical_tween.tween_property(self, "global_position:y", landing_y, MOVE_DURATION * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	_vertical_tween.finished.connect(_on_land, CONNECT_ONE_SHOT)

func _on_land() -> void:
	# 1. 파티클 실행
	landing_particles.restart() # 이전 파티클이 끝나기 전 다시 눌러도 중첩 실행되게 함
	landing_particles.emitting = true
	
	# 2. 기존의 쫀득한 스케일 효과
	var juice_tween = create_tween()
	juice_tween.tween_property(visual, "scale", Vector3(1.3, 0.7, 1.3), 0.04)
	juice_tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
	
	# [Fix] Force visual update AFTER arrival
	# Ensures proximity lighting (Flashlight) uses the new position
	GameManager.player_moved.emit()
