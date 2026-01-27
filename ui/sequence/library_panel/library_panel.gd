extends PanelContainer

signal close_requested

@onready var close_button: Button = %CloseButton
@onready var preset_list_container: VBoxContainer = %PresetListContainer
@onready var name_input: LineEdit = %NameInput
@onready var save_button: Button = %SaveButton

var preset_item_scene: PackedScene = preload("res://ui/sequence/library_panel/preset_item.tscn")
var selected_preset_name: String = "" # [New] Track selection

func _ready() -> void:
	close_button.pressed.connect(func(): close_requested.emit())
	save_button.pressed.connect(_on_save_pressed)
	
	# Initial Refresh
	refresh_list()

func refresh_list() -> void:
	# Clear
	for child in preset_list_container.get_children():
		child.queue_free()
	
	# Fetch
	var list = ProgressionManager.get_preset_list()
	
	# Populate
	for i in range(list.size()):
		var data = list[i]
		var item = preset_item_scene.instantiate()
		preset_list_container.add_child(item)
		item.setup(data, i) # Pass Index
		item.load_requested.connect(_on_load_requested)
		item.delete_requested.connect(_on_delete_requested)
		
		# Connect selection & default signals
		if item.has_signal("item_clicked"):
			item.item_clicked.connect(_on_item_clicked)
		if item.has_signal("set_default_requested"):
			item.set_default_requested.connect(_on_preset_set_default)
		if item.has_signal("reorder_requested"):
			item.reorder_requested.connect(_on_reorder_requested)
			
		# Set Default State
		if item.has_method("set_is_default"):
			var is_def = (data.name == GameManager.default_preset_name)
			item.set_is_default(is_def)
			
	# Restore selection if exists
	if not selected_preset_name.is_empty():
		_update_selection_visuals()

func _on_save_pressed() -> void:
	var input_name = name_input.text.strip_edges()
	var target_name = ""
	
	if not input_name.is_empty():
		# 1. 입력된 이름이 있으면 그것으로 저장 (New / Overwrite by typing)
		target_name = input_name
	elif not selected_preset_name.is_empty():
		# 2. 입력이 없고 선택된 항목이 있으면 덮어쓰기
		target_name = selected_preset_name
	else:
		return # 둘 다 없으면 무시
		
	ProgressionManager.save_preset(target_name)
	name_input.text = "" # Clear input
	
	# 저장 후 선택 상태는 유지? 아니면 해제?
	# "덮어쓰기는 저장된 항목 클릭하고 저장버튼" -> 유지하는게 자연스러움.
	# 하지만 리스트가 새로고침되므로 다시 찾아야 함.
	# 3. 저장 후 선택 해제 (요청사항 반영)
	selected_preset_name = ""
	refresh_list()

func _on_load_requested(name: String) -> void:
	ProgressionManager.load_preset(name)
	
	# 1. 선택 해제
	selected_preset_name = ""
	_update_selection_visuals()
	
	# 2. 세팅창 닫기 (HUD에 요청)
	# EventBus.settings_visibility_changed(false)는 상태 알림용이므로 부적절할 수 있음.
	# HUD가 settings_visibility_changed를 수신해서 창을 닫는지 확인 필요.
	# 하지만 HUD가 EventBus.request_toggle_settings를 받으므로, 창이 열려있는지 확인하고 토글해야 함.
	# 더 확실한 방법: EventBus에 'request_close_settings' 같은 명시적 시그널을 추가하거나,
	# settings_visibility_changed를 "요청"으로도 사용 (HUD 코드 확인 필요).
	# 일단 HUD 코드를 확인하지 않았으므로, EventBus에 'force_close_settings' 시그널 추가 고려.
	# 또는 기존 시그널 활용. 
	# EventBus에 request_close_popups 같은게 있으면 좋음.
	# 일단 HUD를 위해 EventBus.request_toggle_settings 사용? 아니면 새로 추가?
	# HUD 코드를 못 봤으니 안전하게 request_toggle_settings만으로는 상태를 모름.
	# EventBus에 'request_force_close_settings' 추가하자.
	EventBus.request_close_settings.emit() # [New]

func _on_delete_requested(name: String) -> void:
	ProgressionManager.delete_preset(name)
	if selected_preset_name == name:
		selected_preset_name = ""
	refresh_list()

func _on_item_clicked(name: String) -> void:
	# Toggle or Select
	if selected_preset_name == name:
		selected_preset_name = "" # Deselect if clicked again
	else:
		selected_preset_name = name
		name_input.text = "" # Explicit selection clears manual input to avoid ambiguity?
	
	_update_selection_visuals()

func _update_selection_visuals() -> void:
	for child in preset_list_container.get_children():
		if child.has_method("set_selected"):
			var is_target = (child.preset_name == selected_preset_name)
			child.set_selected(is_target)

func _on_preset_set_default(name: String, is_default: bool) -> void:
	if is_default:
		GameManager.default_preset_name = name
	else:
		if GameManager.default_preset_name == name:
			GameManager.default_preset_name = ""
			
	GameManager.save_settings()
	refresh_list() # Update UI (stars)

func _on_reorder_requested(from_idx: int, to_idx: int) -> void:
	ProgressionManager.reorder_presets(from_idx, to_idx)
	refresh_list()
