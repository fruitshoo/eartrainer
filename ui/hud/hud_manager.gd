extends CanvasLayer

# 1. 여기서 변수를 선언해줘야 에러가 안 납니다!
@onready var key_label = %KeyLabel
@onready var chord_label = %ChordLabel

func _ready():
	# 게임 설정(키, 모드 등)이 바뀔 때마다 HUD를 업데이트합니다.
	GameManager.settings_changed.connect(update_hud)
	update_hud()

func update_hud():
	# 2. 안전장치: 노드가 아직 준비되지 않았으면 그냥 돌아갑니다.
	if key_label == null or chord_label == null:
		return
		
	# 3. [% 12]를 붙여서 미디 번호(48, 60 등)가 들어와도 0~11 사이의 음 이름을 찾게 합니다.
	var key_index = GameManager.current_root_note % 12
	var key_name = MusicTheory.CDE_NAMES[key_index]
	
	# 현재 모드 표시 (MAJOR / MINOR)
	var mode_str = "MAJOR"
	if GameManager.current_scale_mode == MusicTheory.ScaleMode.MINOR:
		mode_str = "MINOR"
	
	key_label.text = "[ %s %s ]" % [key_name, mode_str]
	
	# 4. 여기도 [% 12] 필수! 시퀀서에서 보낸 48번 미디 번호를 "C"로 변환합니다.
	var chord_root_index = GameManager.current_chord_root % 12
	var chord_root_name = MusicTheory.CDE_NAMES[chord_root_index]
	var chord_type = GameManager.current_chord_type
	
	chord_label.text = chord_root_name + " " + chord_type
	chord_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
