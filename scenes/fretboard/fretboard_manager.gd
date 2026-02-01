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