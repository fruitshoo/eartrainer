extends CanvasLayer

@onready var slot_container = %SlotContainer
@onready var sequencer = %Sequencer # 유니크 네임 권장 (%)
@onready var play_button = %PlayButton

func _ready():
	# 1. 슬롯들만 신호를 연결합니다. (플레이 버튼은 제외)
	for i in range(slot_container.get_child_count()):
		var slot = slot_container.get_child(i)
		
		# [핵심 수정] 만약 이 노드가 플레이 버튼이면 건너뜁니다!
		if slot == play_button:
			continue
			
		slot.pressed.connect(_on_slot_pressed.bind(i))
	
	ProgressionManager.slot_selected.connect(_update_selection_visual)
	ProgressionManager.data_changed.connect(_on_data_changed)
	play_button.pressed.connect(_on_play_button_pressed)
	sequencer.beat_started.connect(_on_sequencer_step_changed)
	
	_update_selection_visual(0)

func _unhandled_input(event):
	# event.pressed를 체크하고, is_echo(꾹 누르고 있을 때 반복 발생)를 막아야 합니다.
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			_on_play_button_pressed()
			# 이 이벤트가 처리되었음을 알려서 다른 노드로 전달되는 것을 막습니다.
			get_viewport().set_input_as_handled()

func _on_slot_pressed(index: int):
	# 슬롯 범위(0~3)를 벗어나는 클릭은 무시합니다.
	if index >= 4: return
	ProgressionManager.selected_slot_index = index

func _update_selection_visual(selected_index: int):
	for i in range(slot_container.get_child_count()):
		var slot = slot_container.get_child(i)
		if slot == play_button: continue # 플레이 버튼은 색상 변경 제외
		
		if i == selected_index:
			slot.modulate = Color(1.5, 1.5, 1.0)
		else:
			slot.modulate = Color(1, 1, 1)

func _on_data_changed(index: int, data: Dictionary):
	# 플레이 버튼 인덱스로 데이터가 들어오면 무시합니다.
	if index >= slot_container.get_child_count() or index >= 4: return
	
	var slot = slot_container.get_child(index)
	var label = slot.get_node("Label")
	
	var root_name = MusicTheory.CDE_NAMES[data.root % 12]
	var full_chord_name = "%s %s" % [root_name, data.type]
	
	var degree = MusicTheory.get_degree_label(
		data.root,
		GameManager.current_root_note,
		GameManager.current_scale_mode
	)
	
	label.text = "%s\n(%s)" % [degree, full_chord_name]

func _on_play_button_pressed():
	sequencer.toggle_play()
	play_button.text = "STOP" if sequencer.is_playing else "PLAY"

func _on_sequencer_step_changed(index: int):
	for i in range(slot_container.get_child_count()):
		var slot = slot_container.get_child(i)
		if slot == play_button: continue
		
		if i == index:
			slot.modulate = Color(0.5, 2.0, 0.5)
		else:
			# 현재 선택된(편집 중인) 칸은 노란색 유지를 위해 예외 처리
			if i == ProgressionManager.selected_slot_index:
				slot.modulate = Color(1.5, 1.5, 1.0)
			else:
				slot.modulate = Color(1, 1, 1)