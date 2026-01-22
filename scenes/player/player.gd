extends Node3D

@onready var visual = $Visual

var is_jumping: bool = false
var jump_height: float = 2.0
var jump_duration: float = 0.25

func _ready() -> void:
	GameManager.current_player = self
	EventBus.tile_clicked.connect(_on_tile_clicked)

func _on_tile_clicked(_midi_note: int, _string_index: int, modifiers: Dictionary) -> void:
	var target_pos: Vector3 = modifiers.get("position", global_position)
	var fret_index: int = modifiers.get("fret_index", 0)
	
	jump_to(target_pos)
	GameManager.player_fret = fret_index

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
