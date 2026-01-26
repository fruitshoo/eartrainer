extends Camera3D

@export var follow_speed: float = 8.0
@export var zoom_lerp_speed: float = 10.0
@export var drag_sensitivity: float = 1.0
@export var deadzone_radius: float = 4.0

var base_offset: Vector3 = Vector3(10, 8, -10)
var base_rotation: Vector3 = Vector3(-30, 135, 0)

var drag_offset: Vector3 = Vector3.ZERO
var target_size: float = 10.0
var is_dragging: bool = false

func _ready():
	global_position = base_offset
	rotation_degrees = base_rotation
	if projection == ProjectionType.PROJECTION_ORTHOGONAL:
		size = target_size

func _process(delta):
	if not GameManager.current_player: return

	# 1. 줌(Size) 처리
	if projection == ProjectionType.PROJECTION_ORTHOGONAL:
		size = lerp(size, target_size, delta * zoom_lerp_speed)

	# 2. 위치 처리
	var player_pos = GameManager.current_player.global_position
	var target_camera_pos = player_pos + base_offset + drag_offset

	if is_dragging:
		# 드래그 중에는 1:1 밀착
		global_position = target_camera_pos
	else:
		# 드래그 중이 아닐 때만 소프트 데드존 로직
		var current_center = global_position - base_offset - drag_offset
		var to_player = player_pos - current_center
		var distance = to_player.length()
		
		# [Updated] Use GameManager setting
		var deadzone = GameManager.camera_deadzone

		if distance > deadzone:
			var overflow = to_player.normalized() * (distance - deadzone)
			var smooth_target = global_position + overflow
			global_position = global_position.lerp(smooth_target, delta * follow_speed)

func _unhandled_input(event):
	# 줌 로직
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_size = clamp(target_size - 1.0, 3.0, 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_size = clamp(target_size + 1.0, 3.0, 20.0)
		
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				# [핵심] 클릭하는 순간 현재 카메라 위치를 기준으로 오프셋을 동기화
				# 이렇게 하면 클릭 시점에 카메라가 캐릭터 쪽으로 튀지 않습니다.
				var player_pos = GameManager.current_player.global_position
				drag_offset = global_position - player_pos - base_offset
				is_dragging = true
			else:
				is_dragging = false
				
			if event.double_click:
				reset_view()

	# 드래그 로직
	if event is InputEventMouseMotion and is_dragging:
		var viewport_height = get_viewport().get_visible_rect().size.y
		var pixel_to_unit = size / viewport_height
		
		var right_dir = transform.basis.x
		right_dir.y = 0
		right_dir = right_dir.normalized()
		
		var forward_dir = Vector3(right_dir.z, 0, -right_dir.x)
		var move_vec = (right_dir * event.relative.x + forward_dir * -event.relative.y) * pixel_to_unit * drag_sensitivity
		
		drag_offset -= move_vec

func reset_view():
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "drag_offset", Vector3.ZERO, 0.5)
	tween.tween_property(self, "target_size", 10.0, 0.5)