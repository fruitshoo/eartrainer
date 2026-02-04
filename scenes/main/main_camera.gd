extends Camera3D

@export_group("Smoothness")
@export var follow_speed: float = 8.0 # Player tracking speed
@export var zoom_lerp_speed: float = 10.0
@export var rotation_speed: float = 10.0 # [New] Orbit smoothing speed
@export var pan_speed: float = 10.0 # [New] Drag smoothing speed
@export var deadzone_radius: float = 4.0

@export_group("Sensitivity")
@export var drag_sensitivity: float = 1.0
@export var orbit_sensitivity: float = 0.5

# DOF Settings
@export var dof_sharpness_range: float = 8.0

# Orbit / Spherical State
# Default viewing angle from (18, 14, -18) to (0,0,0)
# Vector: (18, 14, -18). Length ~29.
var base_distance: float = 29.0

# Current Interpolated Values
var current_yaw: float = deg_to_rad(135.0)
var current_pitch: float = deg_to_rad(-30.0)
var drag_offset: Vector3 = Vector3.ZERO
var current_zoom: float = 1.0
var current_pivot: Vector3 = Vector3.ZERO

# Target Values (For Smoothing)
var target_yaw: float = deg_to_rad(135.0)
var target_pitch: float = deg_to_rad(-30.0)
var target_drag_offset: Vector3 = Vector3.ZERO
var target_size: float = 10.0

var is_dragging: bool = false
var is_orbiting: bool = false

func _ready():
	# Initial Setup
	if GameManager.current_player:
		current_pivot = GameManager.current_player.global_position
	else:
		current_pivot = Vector3.ZERO
	
	current_zoom = 1.0
	
	# Sync Targets
	target_yaw = current_yaw
	target_pitch = current_pitch
	target_drag_offset = drag_offset
	
	# [v0.8] Monument Valley Style: Orthogonal
	projection = ProjectionType.PROJECTION_ORTHOGONAL
	size = target_size # Initialize size
	
	_update_transform()

func _process(delta):
	# -----------------------------------------------
	# 1. Update Zoom (Smooth)
	# -----------------------------------------------
	# For Orthogonal: 'size' is the view extent. 
	# We interpolate 'size' directly.
	size = lerp(size, target_size, delta * zoom_lerp_speed)
	current_zoom = size / 10.0 # Maintain legacy 'zoom factor' for other calcs if needed

	# -----------------------------------------------
	# 2. Update Orbit Rotation (Smooth)
	# -----------------------------------------------
	
	# [Fix] Dynamic Pitch Constraint (Prevent Clipping when Close)
	# When Zoomed In (0.3), force steeper angle (max -45 deg).
	# When Zoomed Out (1.0+), allow shallow angle (max -15 deg).
	var dynamic_max_pitch_deg = remap(current_zoom, 0.3, 1.0, -45.0, -15.0)
	dynamic_max_pitch_deg = clamp(dynamic_max_pitch_deg, -85.0, -15.0)
	var dynamic_max_pitch = deg_to_rad(dynamic_max_pitch_deg)
	
	# Continually constrain target_pitch
	if target_pitch > dynamic_max_pitch:
		target_pitch = dynamic_max_pitch
	
	current_yaw = lerp(current_yaw, target_yaw, delta * rotation_speed)
	current_pitch = lerp(current_pitch, target_pitch, delta * rotation_speed)

	# -----------------------------------------------
	# 3. Update Pan/Drag (Smooth)
	# -----------------------------------------------
	drag_offset = drag_offset.lerp(target_drag_offset, delta * pan_speed)

	# -----------------------------------------------
	# 4. Update Pivot (Tracking Player)
	# -----------------------------------------------
	if GameManager.current_player and not is_dragging:
		var player_pos = GameManager.current_player.global_position
		
		# Deadzone Logic
		var deadzone = deadzone_radius
		if "camera_deadzone" in GameManager:
			deadzone = GameManager.camera_deadzone
			
		var dist = current_pivot.distance_to(player_pos)
		if dist > deadzone:
			var to_player = player_pos - current_pivot
			var overflow = to_player.normalized() * (dist - deadzone)
			current_pivot = current_pivot.lerp(current_pivot + overflow, delta * follow_speed)
	
	# -----------------------------------------------
	# 5. Update Transform
	# -----------------------------------------------
	_update_transform()
	
	# -----------------------------------------------
	# 5. Update Transform
	# -----------------------------------------------
	_update_transform()
	
	# [v0.8.1] DOF Focus for Ortho/Perspective
	# Update focus distance regardless of projection to prevent blurry artifacts
	
	# [Fix] Auto-Focus: Use exact player position (ignoring deadzone/smoothing)
	var focus_target = current_pivot # Default fallback
	if GameManager.current_player:
		focus_target = GameManager.current_player.global_position
		
	focus_target += drag_offset # Include pan offset? Probably yes, since user looks there.
	
	_update_dof(focus_target)

func _update_transform():
	# Calculate Position from Spherical Coords
	var rot_basis = Basis.from_euler(Vector3(current_pitch, current_yaw, 0))
	var offset_vector = rot_basis * Vector3(0, 0, base_distance * current_zoom)
	
	global_position = current_pivot + offset_vector + drag_offset
	rotation = Vector3(current_pitch, current_yaw, 0)

func _update_dof(target_pos: Vector3):
	if not attributes or not (attributes is CameraAttributesPractical): return
	
	var dist = global_position.distance_to(target_pos)
	
	# [Fix] Zoom-based DOF Intensity
	# When Zoomed In (Size small, current_zoom small) -> High Blur (0.1)
	# When Zoomed Out (Size large, current_zoom large) -> Low Blur (0.0)
	
	# current_zoom: 0.3 (Close) ~ 2.0 (Far)
	# Remap: 0.5 -> 1.0 Blur, 1.5 -> 0.0 Blur
	var blur_intensity = remap(current_zoom, 0.5, 1.5, 0.1, 0.0)
	blur_intensity = clamp(blur_intensity, 0.0, 0.1)
	
	attributes.dof_blur_amount = blur_intensity
	
	# Also control Range
	var dynamic_range = dof_sharpness_range * current_zoom
	
	attributes.dof_blur_far_distance = dist + dynamic_range
	attributes.dof_blur_near_distance = max(0.1, dist - dynamic_range)
	
	# Fully disable if blur is effectively zero to save performance/artifacts
	var dof_enabled = blur_intensity > 0.001
	attributes.dof_blur_far_enabled = dof_enabled
	attributes.dof_blur_near_enabled = dof_enabled

func _unhandled_input(event):
	if event is InputEventMouseButton:
		# Zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_size = clamp(target_size - 1.0, 3.0, 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_size = clamp(target_size + 1.0, 3.0, 20.0)
		
		# Middle Button -> Pan
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				is_orbiting = false
			else:
				is_dragging = false
			
			if event.double_click:
				reset_view()

	# Right Button -> Orbit
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_orbiting = true
				is_dragging = false
				# [Fix] Use HIDDEN instead of CAPTURED to avoid cursor centering jump
				# This limits rotation to screen bounds, but prevents the annoying center snap.
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			else:
				is_orbiting = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Mouse Motion
	if event is InputEventMouseMotion:
		if is_orbiting:
			# Orbit Logic: Modify Targets
			target_yaw -= event.relative.x * orbit_sensitivity * 0.01
			target_pitch -= event.relative.y * orbit_sensitivity * 0.01
			
			# Clamp Pitch
			# Max pitch -5 was too low (Horizon). Change to -15 to hide desk underside.
			target_pitch = clamp(target_pitch, deg_to_rad(-85), deg_to_rad(-15))
			
		elif is_dragging:
			# Pan Logic: Modify Target Drag Offset
			var viewport_height = get_viewport().get_visible_rect().size.y
			var fov_scale = current_zoom
			var pixel_to_unit = (20.0 / viewport_height) * drag_sensitivity * fov_scale
			
			var right_dir = transform.basis.x
			var up_dir = transform.basis.y
			
			var move_vec = (right_dir * -event.relative.x + up_dir * event.relative.y) * pixel_to_unit
			target_drag_offset += move_vec

func reset_view():
	# Reset Targets
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "target_drag_offset", Vector3.ZERO, 0.5)
	tween.tween_property(self, "target_size", 10.0, 0.5)
	tween.tween_property(self, "target_yaw", deg_to_rad(135.0), 0.5)
	tween.tween_property(self, "target_pitch", deg_to_rad(-30.0), 0.5)