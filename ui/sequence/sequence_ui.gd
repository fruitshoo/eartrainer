# sequence_ui.gd
# 시퀀서 UI 컨트롤러 (슬롯 선택, 재생 버튼)
extends CanvasLayer

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var slot_container: HBoxContainer = %SlotContainer
@onready var sequencer: Node = %Sequencer
@onready var play_button: Button = %PlayButton

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_connect_slot_signals()
	_connect_manager_signals()
	_highlight_selected(0)
	ProgressionManager.selection_cleared.connect(_on_selection_cleared)

func _connect_slot_signals() -> void:
	for i in range(slot_container.get_child_count()):
		var slot := slot_container.get_child(i)
		if slot == play_button:
			continue
		slot.pressed.connect(_on_slot_clicked.bind(i))

func _connect_manager_signals() -> void:
	ProgressionManager.slot_selected.connect(_highlight_selected)
	ProgressionManager.slot_updated.connect(_update_slot_label)
	play_button.pressed.connect(_toggle_playback)
	sequencer.bar_started.connect(_highlight_playing)

# ============================================================
# INPUT
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			_toggle_playback()
			get_viewport().set_input_as_handled()

# ============================================================
# SLOT INTERACTION
# ============================================================
func _on_slot_clicked(index: int) -> void:
	if index >= ProgressionManager.SLOT_COUNT:
		return
	
	# [토글 로직] 이미 선택된 슬롯을 다시 누르면 선택 해제(-1), 아니면 선택
	if ProgressionManager.selected_index == index:
		ProgressionManager.selected_index = -1
	else:
		ProgressionManager.selected_index = index
	
	# 에러가 났던 '_update_button_visuals()' 대신 기존 함수 호출
	_highlight_selected(ProgressionManager.selected_index)

func _highlight_selected(selected: int) -> void:
	for i in range(slot_container.get_child_count()):
		var slot := slot_container.get_child(i)
		if slot == play_button:
			continue
		
		# 선택된 슬롯(노란색), 나머지(흰색)
		# selected가 -1이면 모든 슬롯이 Color.WHITE가 됩니다.
		slot.modulate = Color(1.5, 1.5, 1.0) if i == selected else Color.WHITE

func _update_slot_label(index: int, data: Dictionary) -> void:
	if index >= slot_container.get_child_count() or index >= ProgressionManager.SLOT_COUNT:
		return
	
	var slot := slot_container.get_child(index)
	var label: Label = slot.get_node("Label")
	
	var root_name := MusicTheory.NOTE_NAMES_CDE[data.root % 12]
	var degree := MusicTheory.get_degree_label(data.root, GameManager.current_key, GameManager.current_mode)
	
	label.text = "%s\n(%s %s)" % [degree, root_name, data.type]

# ============================================================
# PLAYBACK CONTROL
# ============================================================
func _toggle_playback() -> void:
	sequencer.toggle_play()
	play_button.text = "STOP" if sequencer.is_playing else "PLAY"

func _highlight_playing(playing_index: int) -> void:
	for i in range(slot_container.get_child_count()):
		var slot := slot_container.get_child(i)
		if slot == play_button:
			continue
		
		if i == playing_index:
			slot.modulate = Color(0.5, 2.0, 0.5) # 재생 중 (녹색)
		elif i == ProgressionManager.selected_index:
			slot.modulate = Color(1.5, 1.5, 1.0) # 선택됨 (노란색)
		else:
			slot.modulate = Color.WHITE

# ============================================================
# SIGNALS FROM MANAGER
# ============================================================
func _on_selection_cleared():
	# 타일 입력을 마쳐서 selected_index가 -1이 되었을 때 호출됩니다.
	# 모든 하이라이트를 끕니다.
	_highlight_selected(-1)
