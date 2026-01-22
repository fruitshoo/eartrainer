extends Node3D

@onready var visual = $Visual

var is_jumping: bool = false
var jump_height: float = 2.0
var jump_duration: float = 0.25

func _ready() -> void:
	GameManager.current_player = self
	EventBus.tile_clicked.connect(_on_tile_clicked)
	# 타일들이 모두 생성된 후 초기 위치로 이동
	call_deferred("_initialize_position")

func _initialize_position() -> void:
	# 한 프레임 더 대기하여 타일 생성 완료 보장
	await get_tree().process_frame
	
	var target_tile = GameManager.find_tile(
		SettingsManager.last_string,
		SettingsManager.last_fret
	)
	if target_tile:
		global_position = target_tile.global_position
		GameManager.player_fret = SettingsManager.last_fret
	else:
		# 타일을 찾지 못하면 기본 위치 (fret 5)
		GameManager.player_fret = SettingsManager.DEFAULT_FRET

func _on_tile_clicked(_midi_note: int, string_index: int, modifiers: Dictionary) -> void:
	var target_pos: Vector3 = modifiers.get("position", global_position)
	var fret_index: int = modifiers.get("fret_index", 0)
	
	jump_to(target_pos)
	GameManager.player_fret = fret_index
	SettingsManager.last_string = string_index # 위치 저장용

func jump_to(target_pos: Vector3):
	if is_jumping: return
	
	is_jumping = true
	
	# 1. 수평 이동 (동시에 실행되어야 하므로 set_parallel 사용)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:x", target_pos.x, jump_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position:z", target_pos.z, jump_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. 수직 이동 (올라갔다 내려오는 순서가 필요하므로 기본 Tween 사용)
	var vertical_tween = create_tween() # .set_sequence() 삭제됨
	
	# 올라가기
	vertical_tween.tween_property(self, "global_position:y", jump_height, jump_duration * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 내려오기
	vertical_tween.tween_property(self, "global_position:y", target_pos.y, jump_duration * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 3. 착지 효과 연결
	vertical_tween.finished.connect(_on_land)

func _on_land():
	is_jumping = false
	
	# 착지 시 쫀득하게 눌리는 효과
	var juice_tween = create_tween()
	juice_tween.tween_property(visual, "scale", Vector3(1.4, 0.6, 1.4), 0.05)
	juice_tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
