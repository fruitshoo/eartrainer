extends CanvasLayer

# % 기호는 노드 설정에서 "Access as Unique Name"을 켰을 때 사용합니다.
@onready var key_options = %KeyOptionButton
@onready var mode_options = %ModeOptionButton # 새로 추가된 버튼
@onready var notation_options = %NotationOptionButton
@onready var hint_check = %HintCheckButton

func _ready():
	# [중요] GameManager에게 내 주소를 알려줍니다.
	GameManager.settings_ui_ref = self
	
	# UI 채우기
	setup_ui_content()
	sync_with_game_manager()

	# 3. [핵심] 스크립트에서 신호 직접 연결하기
	# % 기호(Unique Name)를 사용하여 버튼 노드에 접근합니다.
	key_options.item_selected.connect(_on_key_option_button_item_selected)
	mode_options.item_selected.connect(_on_mode_option_selected)
	notation_options.item_selected.connect(_on_notation_option_button_item_selected)
	hint_check.toggled.connect(_on_hint_check_button_toggled)
	
	# 처음에는 숨김
	visible = false

# 1. 내용물 채우기
func setup_ui_content():
	key_options.clear()
	var keys = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	for i in range(keys.size()):
		key_options.add_item(keys[i], i)

	# 스케일 모드 채우기
	mode_options.clear()
	mode_options.add_item("MAJOR", 0)
	mode_options.add_item("MINOR", 1)

	notation_options.clear()
	notation_options.add_item("CDE (English)", 0)
	notation_options.add_item("도레미 (Doremi)", 1)
	notation_options.add_item("둘 다 표시 (Both)", 2)

# 2. GameManager의 현재 값과 UI 동기화
func sync_with_game_manager():
	key_options.selected = GameManager.current_root_note
	mode_options.selected = GameManager.current_scale_mode
	notation_options.selected = GameManager.current_notation
	hint_check.button_pressed = GameManager.is_hint_visible

# --- 신호(Signal) 연결 부분 ---

func _on_key_option_button_item_selected(index):
	GameManager.current_root_note = index

func _on_mode_option_selected(index):
	GameManager.current_scale_mode = index as GameManager.ScaleMode

func _on_notation_option_button_item_selected(index):
	GameManager.current_notation = index as GameManager.NotationMode

func _on_hint_check_button_toggled(toggled_on):
	GameManager.is_hint_visible = toggled_on

func _on_close_button_pressed():
	visible = false
