extends Node3D

@export var tile_scene: PackedScene = preload("res://scenes/tile/fret_tile.tscn")

const STRINGS = 6
const FRETS = 13 # 0프렛 포함
const SPACING = 1.5

# 기타 조율 (6번줄부터 1번줄 순서: E2, A2, D3, G3, B3, E4)
# MIDI: 40(E2), 45(A2), 50(D3), 55(G3), 59(B3), 64(E4)
var string_root_notes = [40, 45, 50, 55, 59, 64]

func _ready():
	spawn_fretboard()

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
			
			tile.position = Vector3(x_pos, 0, z_pos)
			
			# [타일 정보 설정]
			# s=0 이 6번줄(낮은 E)이므로 순서대로 매칭
			var note = string_root_notes[s] + f
			tile.setup(s, f, note)