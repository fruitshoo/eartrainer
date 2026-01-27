# settings_ui.gd
# 설정 패널 UI 컨트롤러
extends CanvasLayer

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var key_option: OptionButton = %KeyOptionButton
@onready var mode_option: OptionButton = %ModeOptionButton
@onready var notation_option: OptionButton = %NotationOptionButton
@onready var rhythm_toggle: CheckButton = %RhythmCheckButton
@onready var note_label_check: CheckBox = %NoteLabelCheck
@onready var root_check: CheckBox = %RootCheck
@onready var chord_check: CheckBox = %ChordCheck
@onready var scale_check: CheckBox = %ScaleCheck
@onready var range_label: Label = %ValueLabel
@onready var minus_btn: Button = %MinusButton
@onready var plus_btn: Button = %PlusButton
# [New] Camera Deadzone
@onready var deadzone_value: Label = %DeadzoneValue
@onready var deadzone_minus: Button = %DeadzoneMinus
@onready var deadzone_plus: Button = %DeadzonePlus

# 메트로놈 컨트롤
@onready var metronome_toggle: CheckButton = %MetronomeToggle
@onready var close_btn: Button = %CloseButton

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	# GameManager.settings_ui_ref = self # 제거됨
	EventBus.request_toggle_settings.connect(_on_request_toggle_settings)
	EventBus.request_close_settings.connect(_on_close_button_pressed) # [New] explicit close
	
	_populate_options()
	_sync_from_game_manager()
	_connect_signals()
	
	visibility_changed.connect(_on_visibility_changed)
	visible = false

func _on_request_toggle_settings() -> void:
	visible = !visible
	if visible:
		EventBus.request_close_library.emit() # [New] Close Library if Settings open

func _on_visibility_changed() -> void:
	EventBus.settings_visibility_changed.emit(visible)
	if visible:
		_sync_from_game_manager()

# ============================================================
# SETUP
# ============================================================
func _populate_options() -> void:
	key_option.clear()
	for i in range(MusicTheory.NOTE_NAMES_CDE.size()):
		key_option.add_item(MusicTheory.NOTE_NAMES_CDE[i], i)
	
	mode_option.clear()
	mode_option.add_item("MAJOR", 0)
	mode_option.add_item("MINOR", 1)
	
	notation_option.clear()
	notation_option.add_item("CDE (English)", 0)
	notation_option.add_item("도레미 (Doremi)", 1)
	notation_option.add_item("둘 다 (Both)", 2)

func _sync_from_game_manager() -> void:
	key_option.selected = GameManager.current_key
	mode_option.selected = GameManager.current_mode
	notation_option.selected = GameManager.current_notation
	rhythm_toggle.button_pressed = GameManager.is_rhythm_mode_enabled
	note_label_check.button_pressed = GameManager.show_note_labels
	root_check.button_pressed = GameManager.highlight_root
	chord_check.button_pressed = GameManager.highlight_chord
	scale_check.button_pressed = GameManager.highlight_scale
	
	_update_range_label()
	_update_deadzone_label()
	
	if metronome_toggle:
		metronome_toggle.button_pressed = GameManager.is_metronome_enabled

func _connect_signals() -> void:
	key_option.item_selected.connect(_on_key_changed)
	mode_option.item_selected.connect(_on_mode_changed)
	notation_option.item_selected.connect(_on_notation_changed)
	rhythm_toggle.toggled.connect(_on_rhythm_toggled)
	note_label_check.toggled.connect(func(enabled): GameManager.show_note_labels = enabled)
	root_check.toggled.connect(func(enabled): GameManager.highlight_root = enabled)
	chord_check.toggled.connect(func(enabled): GameManager.highlight_chord = enabled)
	scale_check.toggled.connect(func(enabled): GameManager.highlight_scale = enabled)
	
	if minus_btn:
		minus_btn.pressed.connect(_on_range_decrease)
	if plus_btn:
		plus_btn.pressed.connect(_on_range_increase)
		
	# [New] Deadzone Signals
	if deadzone_minus:
		deadzone_minus.pressed.connect(_on_deadzone_decrease)
	if deadzone_plus:
		deadzone_plus.pressed.connect(_on_deadzone_increase)
	
	# 메트로놈 시그널
	if metronome_toggle:
		metronome_toggle.toggled.connect(_on_metronome_toggled)
	
	# 닫기 버튼
	if close_btn:
		close_btn.pressed.connect(_on_close_button_pressed)

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_key_changed(index: int) -> void:
	GameManager.current_key = index

func _on_mode_changed(index: int) -> void:
	GameManager.current_mode = index as MusicTheory.ScaleMode

func _on_notation_changed(index: int) -> void:
	GameManager.current_notation = index as MusicTheory.NotationMode

func _on_rhythm_toggled(enabled: bool) -> void:
	GameManager.is_rhythm_mode_enabled = enabled


func _on_range_decrease() -> void:
	GameManager.focus_range = clampi(GameManager.focus_range - 1, 1, 12)
	_update_range_label()

func _on_range_increase() -> void:
	GameManager.focus_range = clampi(GameManager.focus_range + 1, 1, 12)
	_update_range_label()

# [New] Deadzone Handlers
func _on_deadzone_decrease() -> void:
	GameManager.camera_deadzone = clampf(GameManager.camera_deadzone - 0.5, 0.0, 10.0)
	_update_deadzone_label()

func _on_deadzone_increase() -> void:
	GameManager.camera_deadzone = clampf(GameManager.camera_deadzone + 0.5, 0.0, 10.0)
	_update_deadzone_label()

func _on_close_button_pressed() -> void:
	visible = false

func _on_metronome_toggled(enabled: bool) -> void:
	GameManager.is_metronome_enabled = enabled

# ============================================================
# HELPERS
# ============================================================
func _update_range_label() -> void:
	if range_label:
		range_label.text = str(GameManager.focus_range)

func _update_deadzone_label() -> void:
	if deadzone_value:
		deadzone_value.text = "%.1f" % GameManager.camera_deadzone
