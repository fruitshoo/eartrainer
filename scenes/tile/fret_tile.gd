extends Area3D

var string_index: int = 0
var fret_index: int = 0
var midi_note: int = 0

@onready var label = $Label3D
@onready var mesh_instance = $MeshInstance3D

var current_tween: Tween = null

func _ready():
	# 설정 변경과 캐릭터 이동 신호 모두에 반응
	GameManager.settings_changed.connect(update_appearance)
	GameManager.player_moved.connect(update_appearance)
	update_appearance()

func setup(s: int, f: int, note: int):
	string_index = s
	fret_index = f
	midi_note = note

func update_appearance():
	# 텍스트는 항상 현재 Key 기준 계이름
	label.text = GameManager.get_movable_do_name(midi_note)
	
	if not GameManager.is_hint_visible:
		label.visible = false
		apply_visual_tier(Color(0.1, 0.1, 0.1), 0.0)
		return

	# 캐릭터 포커스 범위 확인 (연주자의 시선)
	var distance = abs(fret_index - GameManager.player_fret)
	var is_in_focus = distance <= GameManager.focus_range

	# --- 3계층 시각화 논리 ---
	var relative_to_key = (midi_note - GameManager.current_root_note) % 12
	if relative_to_key < 0: relative_to_key += 12
	
	var is_key_root = (relative_to_key == 0) # 레이어 3: 북극성
	var tier = GameManager.get_note_tier(midi_note) # 레이어 2: 코드톤 확인
	
	# [수정] 메이저/마이너 통합 함수로 교체
	var is_in_key = GameManager.is_note_in_scale(midi_note) # 레이어 1: 가로등

	# 포커스 밖에 있는 타일들은 아주 최소한의 정보(가로등)만 남김
	if not is_in_focus:
		label.visible = false
		if is_key_root: # 포커스 밖이라도 북극성은 희미하게 보임
			apply_visual_tier(Color(0.8, 0.6, 0.2), 0.3)
		elif is_in_key: # 가로등 역할
			apply_visual_tier(Color(0.2, 0.2, 0.2), 0.05)
		else:
			apply_visual_tier(Color(0.05, 0.05, 0.05), 0.0)
		return

	# 포커스 안 (집중 구역)
	label.visible = true
	
	if is_key_root:
		# 레이어 3: 북극성 (황금색, 언제나 가장 눈에 띔)
		apply_visual_tier(Color(1.0, 0.8, 0.2), 2.5)
	elif tier == 1 or tier == 2:
		# 레이어 2: 코드톤 (밝은 하늘색, 현재의 착지점)
		apply_visual_tier(Color(0.3, 0.8, 1.0), 1.8)
	elif is_in_key:
		# 레이어 1: 가로등 (은은한 회색, 이동 경로)
		apply_visual_tier(Color(0.4, 0.4, 0.4), 0.3)
	else:
		# 스케일 외 (어보이드/크로매틱, 어둡게)
		label.visible = false
		apply_visual_tier(Color(0.05, 0.05, 0.05), 0.0)

func apply_visual_tier(color: Color, energy: float):
	var mat = mesh_instance.get_surface_override_material(0)
	if not mat:
		mat = mesh_instance.get_active_material(0).duplicate()
		mesh_instance.set_surface_override_material(0, mat)
	
	# [수정] 이전 트윈이 실행 중이면 정지시켜서 반응 속도 개선
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(mat, "albedo_color", color, 0.2)
	
	if energy > 0:
		mat.emission_enabled = true
		current_tween.tween_property(mat, "emission", color, 0.2)
		current_tween.tween_property(mat, "emission_energy_multiplier", energy, 0.2)
	else:
		# 에너지가 0일 때 확실히 꺼지도록 수정
		current_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.2)

func _input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on_tile_clicked()

func on_tile_clicked():
	if GameManager.current_player:
		GameManager.current_player.jump_to(global_position)
		# 중요: 캐릭터가 이동한 타일의 프렛 정보를 GameManager에 알림
		GameManager.player_fret = fret_index
		
	AudioEngine.play_note(midi_note)
	if QuizManager: QuizManager.check_answer(midi_note)
