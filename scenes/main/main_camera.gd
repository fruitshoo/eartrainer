extends Camera3D

@export var follow_speed: float = 8.0
@export var zoom_lerp_speed: float = 10.0
@export var drag_sensitivity: float = 1.0
@export var deadzone_radius: float = 4.0

# DOF Settings
@export var dof_sharpness_range: float = 8.0 # Range around focus point that stays sharp

var base_offset: Vector3 = Vector3(18, 14, -18) # Updated for Perspective/Telephoto
var base_rotation: Vector3 = Vector3(-30, 135, 0)

var drag_offset: Vector3 = Vector3.ZERO
var target_size: float = 10.0 # Used for Ortho Size OR Perspective Zoom Factor
var current_zoom: float = 1.0 # Multiplier for base_offset length

var is_dragging: bool = false

func _ready():
	# Initial Setup
	if projection == ProjectionType.PROJECTION_ORTHOGONAL:
		global_position = base_offset
		size = target_size
	else:
		# For Perspective, we use current distance as base
		current_zoom = 1.0
		# base_offset is already set in script but better to grab from transform if customized
		# base_offset = global_position # Uncomment if we want to respect editor position

	rotation_degrees = base_rotation

func _process(delta):
	if not GameManager.current_player: return

	var player_pos = GameManager.current_player.global_position
	
	# 1. Zoom Logic
	if projection == ProjectionType.PROJECTION_ORTHOGONAL:
		size = lerp(size, target_size, delta * zoom_lerp_speed)
		# Ortho doesn't move camera for zoom, just changes size
		var target_camera_pos = player_pos + base_offset + drag_offset
		_apply_position(target_camera_pos, player_pos, delta)
		
	else: # Perspective
		# Zoom means moving closer/further
		# target_size (3 to 20) -> Map to Zoom Factor (e.g. 0.3 to 2.0)
		# Let's say target_size=10 is 1.0. 
		var target_factor = target_size / 10.0
		current_zoom = lerp(current_zoom, target_factor, delta * zoom_lerp_speed)
		
		var effective_offset = base_offset * current_zoom
		var target_camera_pos = player_pos + effective_offset + drag_offset
		_apply_position(target_camera_pos, player_pos, delta)
		
		_update_dof(player_pos)

func _apply_position(target_pos: Vector3, player_pos: Vector3, delta: float):
	if is_dragging:
		global_position = target_pos
	else:
		# Soft Deadzone
		# Calculate where camera SHOULD be relative to player (Ideal)
		# Wait, simplistic logic:
		# Just strictly follow if outside deadzone
		# Current implementation logic was: 
		# 1. Calculate ideal center 
		# 2. If player too far from ideal center, move camera.
		# Let's simplify: 
		# The Camera looks at the player. 
		# If we strictly track, it's boring. 
		# Current pos
		var desired_pos = target_pos
		global_position = global_position.lerp(desired_pos, delta * follow_speed)

func _update_dof(player_pos: Vector3):
	if not attributes: return
	if not attributes is CameraAttributesPractical: return
	
	var dist = global_position.distance_to(player_pos)
	
	# Dynamic Sharpeness: Zoomed in (Low dist) -> Tighter range?
	# Or user said "Zoom in/out affects DOF values".
	# Fixed range is usually fine, but let's scale it slightly.
	# If current_zoom is small (0.5), range is smaller.
	var dynamic_range = dof_sharpness_range * current_zoom
	
	attributes.dof_blur_far_distance = dist + dynamic_range
	attributes.dof_blur_near_distance = max(0.1, dist - dynamic_range)
	
	# Adjust blur amount if needed, but distance is key.

func _unhandled_input(event):
	# Zoom Logic
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom In (Smaller size / value)
			target_size = clamp(target_size - 1.0, 3.0, 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom Out
			target_size = clamp(target_size + 1.0, 3.0, 20.0)
		
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				var player_pos = GameManager.current_player.global_position
				# Recalculate drag offset to prevent jumping
				# current_pos = player + effective_offset + drag
				# drag = current - player - effective
				var effective_offset = base_offset
				if projection == ProjectionType.PROJECTION_PERSPECTIVE:
					effective_offset = base_offset * (target_size / 10.0) # Approx
					
				drag_offset = global_position - player_pos - effective_offset
				is_dragging = true
			else:
				is_dragging = false
				
			if event.double_click:
				reset_view()

	# Drag Logic
	if event is InputEventMouseMotion and is_dragging:
		var viewport_height = get_viewport().get_visible_rect().size.y
		
		# Sensitivity adjustment for perspective
		var fov_scale = 1.0
		if projection == ProjectionType.PROJECTION_PERSPECTIVE:
			# Larger FOV/Distance = moved more
			fov_scale = current_zoom # Move faster when zoomed out
			
		var pixel_to_unit = (20.0 / viewport_height) * drag_sensitivity * fov_scale
		# Note: 20.0 is arbitrary reference size
		
		var right_dir = transform.basis.x
		right_dir.y = 0
		right_dir = right_dir.normalized()
		
		var forward_dir = Vector3(right_dir.z, 0, -right_dir.x)
		var move_vec = (right_dir * event.relative.x + forward_dir * -event.relative.y) * pixel_to_unit
		
		drag_offset -= move_vec

func reset_view():
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "drag_offset", Vector3.ZERO, 0.5)
	tween.tween_property(self, "target_size", 10.0, 0.5)