# settings_ui.gd
# 설정 패널 UI 컨트롤러
extends CanvasLayer

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var key_option: OptionButton = %KeyOptionButton
@onready var mode_option: OptionButton = %ModeOptionButton
@onready var notation_option: OptionButton = %NotationOptionButton
@onready var hint_toggle: CheckButton = %HintCheckButton
@onready var range_label: Label = %ValueLabel
@onready var minus_btn: Button = %MinusButton
@onready var plus_btn: Button = %PlusButton

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.settings_ui_ref = self
	
	_populate_options()
	_sync_from_game_manager()
	_connect_signals()
	
	visible = false

# ============================================================
# SETUP
# ============================================================
func _populate_options() -> void:
	# 키 선택
	key_option.clear()
	for i in range(MusicTheory.NOTE_NAMES_CDE.size()):
		key_option.add_item(MusicTheory.NOTE_NAMES_CDE[i], i)
	
	# 모드 선택
	mode_option.clear()
	mode_option.add_item("MAJOR", 0)
	mode_option.add_item("MINOR", 1)
	
	# 노테이션 선택
	notation_option.clear()
	notation_option.add_item("CDE (English)", 0)
	notation_option.add_item("도레미 (Doremi)", 1)
	notation_option.add_item("둘 다 (Both)", 2)

func _sync_from_game_manager() -> void:
	key_option.selected = GameManager.current_key
	mode_option.selected = GameManager.current_mode
	notation_option.selected = GameManager.current_notation
	hint_toggle.button_pressed = GameManager.show_hints
	_update_range_label()

func _connect_signals() -> void:
	key_option.item_selected.connect(_on_key_changed)
	mode_option.item_selected.connect(_on_mode_changed)
	notation_option.item_selected.connect(_on_notation_changed)
	hint_toggle.toggled.connect(_on_hint_toggled)
	
	if minus_btn:
		minus_btn.pressed.connect(_on_range_decrease)
	if plus_btn:
		plus_btn.pressed.connect(_on_range_increase)

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_key_changed(index: int) -> void:
	GameManager.current_key = index

func _on_mode_changed(index: int) -> void:
	GameManager.current_mode = index as MusicTheory.ScaleMode

func _on_notation_changed(index: int) -> void:
	GameManager.current_notation = index as MusicTheory.NotationMode

func _on_hint_toggled(enabled: bool) -> void:
	GameManager.show_hints = enabled

func _on_range_decrease() -> void:
	GameManager.focus_range = clampi(GameManager.focus_range - 1, 1, 12)
	_update_range_label()

func _on_range_increase() -> void:
	GameManager.focus_range = clampi(GameManager.focus_range + 1, 1, 12)
	_update_range_label()

func _on_close_button_pressed() -> void:
	visible = false

# ============================================================
# HELPERS
# ============================================================
func _update_range_label() -> void:
	if range_label:
		range_label.text = str(GameManager.focus_range)
