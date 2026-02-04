extends Node3D


func spawn_props() -> void:
	pass
	# 1. Giant Desk Surface
	# Placed below the ground print labels (Y ~ -0.25)
	var desk = MeshInstance3D.new()
	var desk_mesh = BoxMesh.new()
	desk_mesh.size = Vector3(100, 1, 100) # Huge desk
	var desk_mat = StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.15, 0.1, 0.05) # Dark Walnut
	desk_mat.roughness = 0.4
	desk_mesh.material = desk_mat
	desk.mesh = desk_mesh
	desk.name = "DeskSurface"
	desk.position = Vector3(0, -0.8, -10) # Centered somewhat
	add_child(desk)
	
	# 2. Giant Guitar Pick
	# A triangular prism or flattened cylinder (3 sides)
	var pick = MeshInstance3D.new()
	var pick_mesh = CylinderMesh.new()
	pick_mesh.top_radius = 4.0
	pick_mesh.bottom_radius = 4.0
	pick_mesh.height = 0.2
	pick_mesh.radial_segments = 3 # Triangle
	var pick_mat = StandardMaterial3D.new()
	pick_mat.albedo_color = Color(0.9, 0.4, 0.1) # Orange/Tortoise
	pick_mat.metallic = 0.1
	pick_mat.roughness = 0.3
	pick_mesh.material = pick_mat
	pick.mesh = pick_mesh
	pick.name = "GiantPick"
	
	# Place closer to camera/side
	pick.position = Vector3(12, -0.2, 5)
	pick.rotation_degrees = Vector3(0, 30, 0)
	add_child(pick)
	
	# 3. Coiled Cable (Torus)
	# A giant black cable loop in the background
	var cable = MeshInstance3D.new()
	var cable_mesh = TorusMesh.new()
	cable_mesh.outer_radius = 8.0
	cable_mesh.inner_radius = 7.0 # 1.0 thickness
	cable_mesh.rings = 16
	cable_mesh.ring_segments = 32
	var cable_mat = StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.1, 0.1, 0.1) # Black rubber
	cable_mat.roughness = 0.8
	cable_mesh.material = cable_mat
	cable.mesh = cable_mesh
	cable.name = "CoiledCable"
	
	cable.position = Vector3(-15, -0.2, -15)
	cable.rotation_degrees = Vector3(10, 0, 10) # Slightly casual
	add_child(cable)
