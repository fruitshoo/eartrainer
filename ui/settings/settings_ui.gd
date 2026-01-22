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
# 메트로놈 컨트롤
@onready var bpm_slider: HSlider = %BPMSlider
@onready var bpm_input: LineEdit = %BPMLabel # LineEdit으로 사용
@onready var metronome_toggle: CheckButton = %MetronomeToggle
@onready var close_btn: Button = %CloseButton

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
	hint_toggle.button_pressed = GameManager.show_hints
	_update_range_label()
	
	# 메트로놈 동기화
	if bpm_slider:
		bpm_slider.min_value = 40
		bpm_slider.max_value = 240
		bpm_slider.value = GameManager.bpm
	_update_bpm_display()
	if metronome_toggle:
		metronome_toggle.button_pressed = GameManager.is_metronome_enabled

func _connect_signals() -> void:
	key_option.item_selected.connect(_on_key_changed)
	mode_option.item_selected.connect(_on_mode_changed)
	notation_option.item_selected.connect(_on_notation_changed)
	hint_toggle.toggled.connect(_on_hint_toggled)
	
	if minus_btn:
		minus_btn.pressed.connect(_on_range_decrease)
	if plus_btn:
		plus_btn.pressed.connect(_on_range_increase)
	
	# 메트로놈 시그널
	if bpm_slider:
		bpm_slider.value_changed.connect(_on_bpm_slider_changed)
	if bpm_input:
		bpm_input.text_submitted.connect(_on_bpm_text_submitted)
		bpm_input.focus_exited.connect(_on_bpm_focus_exited)
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

## 슬라이더 → 입력칸 동기화
func _on_bpm_slider_changed(value: float) -> void:
	GameManager.bpm = int(value)
	_update_bpm_display()

## 입력칸 → 슬라이더 동기화 (엔터 눌렀을 때)
func _on_bpm_text_submitted(text: String) -> void:
	_apply_bpm_from_text(text)

## 입력칸 포커스 아웃 시 적용
func _on_bpm_focus_exited() -> void:
	if bpm_input:
		_apply_bpm_from_text(bpm_input.text)

func _on_metronome_toggled(enabled: bool) -> void:
	GameManager.is_metronome_enabled = enabled

# ============================================================
# HELPERS
# ============================================================
func _update_range_label() -> void:
	if range_label:
		range_label.text = str(GameManager.focus_range)

func _update_bpm_display() -> void:
	if bpm_input:
		bpm_input.text = str(GameManager.bpm)

## 텍스트 입력값을 BPM으로 변환 및 검증
func _apply_bpm_from_text(text: String) -> void:
	var parsed := text.to_int()
	
	# 숫자가 아니거나 0이면 현재 값 유지
	if parsed <= 0:
		_update_bpm_display()
		return
	
	# 40-240 범위로 클램핑
	var clamped := clampi(parsed, 40, 240)
	GameManager.bpm = clamped
	
	# 슬라이더와 입력칸 동기화
	if bpm_slider:
		bpm_slider.value = clamped
	_update_bpm_display()
