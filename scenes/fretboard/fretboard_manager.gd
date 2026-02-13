extends Node3D

@export var tile_scene: PackedScene = preload("res://scenes/fretboard/tile/fret_tile.tscn")

const STRINGS = 6
const FRETS = 13 # 0프렛 포함
const SPACING = 1.5

# 기타 조율 (6번줄부터 1번줄 순서: E2, A2, D3, G3, B3, E4)
# MIDI: 40(E2), 45(A2), 50(D3), 55(G3), 59(B3), 64(E4)
var string_root_notes = [40, 45, 50, 55, 59, 64]

@onready var labels_layer: CanvasLayer = $Labels

func _ready():
	spawn_fretboard()
	# _spawn_environment_scene() # [Disabled] User will place "scenes/environment/giant_desk.tscn" manually in Main scene.
	call_deferred("_setup_environment")

func spawn_fretboard():
	for s in range(STRINGS):
		for f in range(FRETS):
			var tile = tile_scene.instantiate()
			add_child(tile)
			
			# [좌표 계산]
			# 줄(s): 0(6번줄)일 때 +X, 5(1번줄)로 갈수록 -X
			var x_pos = (2.5 - s) * SPACING # 중앙 정렬을 위해 (STRINGS-1)/2 인 2.5 사용
			
			# 프렛(f): 0프렛일 때 +Z, 12프렛일 때 -Z
			var z_pos = -f * SPACING
			
			# [v0.7] Toy Look: Chunky Tiles
			# Scaling removed by user request (Will be handled in tile.tscn)
			# tile.scale.y = 5.0 
			tile.position = Vector3(x_pos, 0, z_pos)
			
			# [타일 정보 설정]
			# s=0 이 6번줄(낮은 E)이므로 순서대로 매칭
			var note = string_root_notes[s] + f
			tile.setup(s, f, note, labels_layer)
			
	# [New] Side Fret Markers (3, 5, 7, 9, 12)
	spawn_fret_markers()

func spawn_fret_markers() -> void:
	var marker_frets = [0, 3, 5, 7, 9, 12]
	# X Pos: Outside the 6th string, on the "Floor".
	# 6th string center is 3.75. Tile edge is ~4.45 (1.4 width).
	# Let's put it at 5.5 for clear separation.
	# 6th string center is 3.75. Tile edge is ~4.45 (1.4 width).
	# Let's put it at 5.5 for clear separation.
	var x_pos = 5.5
	
	# Load Main Theme for Font
	var main_theme = load("res://ui/resources/main_theme.tres")
	
	for f in marker_frets:
		var label = Label3D.new()
		label.text = str(f)
		
		# Apply Theme Font
		if main_theme and main_theme.default_font:
			label.font = main_theme.default_font
		
		# [Style: Printed on Ground]
		# Flat on the floor
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		# Rotate X -90 -> Flat
		# Rotate Y 90 -> Opposing side text orientation
		label.rotation_degrees = Vector3(-90, 90, 0)
		
		# Visuals (Studio floor marking style)
		label.font_size = 200 # Increased from 150
		label.outline_render_priority = 0
		label.modulate = Color(1, 1, 1, 0.4) # Subtle white marking
		label.alpha_cut = Label3D.ALPHA_CUT_DISABLED # Smooth blending with floor
		label.double_sided = false # Optimization
		
		# Z Position matches fret Z
		var z_pos = -f * SPACING
		# Y Position: Ground Level (Tile bottom is -0.25 if centered at 0 with 0.5 height)
		# Let's put it slightly above ground to avoid z-fighting with a floor plane if exists
		var y_pos = -0.24
		
		label.position = Vector3(x_pos, y_pos, z_pos)
		
		add_child(label)

func _setup_environment() -> void:
	# 1. WorldEnvironment is handled by 'cozy_studio.tres' resource now.
	# We only need to adjust the DirectionalLight here since it's a node property.
	# 2. Lighting (Side Light)
	var sun = get_tree().root.find_child("DirectionalLight3D", true, false)
	if sun:
		sun.rotation_degrees = Vector3(-45, 45, 0) # 45 degree Pitch/Yaw
		sun.shadow_enabled = true
		sun.shadow_blur = 3.0 # Soft shadows
		sun.light_energy = 1.0 # [Fixed] Reduced from 1.2 to prevent overexposure
		sun.light_indirect_energy = 1.0 # [Fixed] Reduced indirect bounce

func _spawn_environment_scene() -> void:
	# Load dedicated environment scene for easier editing
	var scene = load("res://scenes/environment/giant_desk.tscn")
	if scene:
		var instance = scene.instantiate()
		add_child(instance)
