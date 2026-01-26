# slot_button.gd
class_name SlotButton
extends Button

# ============================================================
# STATE
# ============================================================
var slot_index: int = -1

# ============================================================
# NODES
# ============================================================
@onready var label: Label = $Label

# ============================================================
# PUBLIC API
# ============================================================
func setup(index: int) -> void:
	slot_index = index
	text = "" # 버튼 텍스트는 비움 (Label 사용)
	_update_default_visual()

func update_info(data: Dictionary) -> void:
	if not label: return
	
	if data == null or data.is_empty():
		_update_default_visual()
		return

	var use_flats := MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var root_name := MusicTheory.get_note_name(data.root, use_flats)
	var degree := MusicTheory.get_degree_label(data.root, GameManager.current_key, GameManager.current_mode)
	
	label.text = "%s\n(%s%s)" % [degree, root_name, data.type]

func set_highlight(state: String) -> void:
	# state: "playing", "selected", "none"
	match state:
		"playing":
			modulate = Color(0.5, 2.0, 0.5) # 녹색
		"selected":
			modulate = Color(1.5, 1.5, 1.0) # 노란색
		_:
			modulate = Color.WHITE

func _update_default_visual() -> void:
	if label:
		label.text = "Slot %d" % (slot_index + 1)

signal right_clicked(index: int)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(slot_index)
		accept_event()
