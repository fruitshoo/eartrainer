extends HBoxContainer

signal toggled(on: bool)
signal edit_requested()

@onready var checkbox: CheckBox = %CheckBox
@onready var edit_button: Button = %EditButton
@onready var spacer: Control = %Spacer

func setup(text: String, is_checked: bool, show_edit: bool = true):
	if not is_node_ready(): await ready
	
	checkbox.text = text
	checkbox.button_pressed = is_checked
	
	edit_button.visible = show_edit
	
	# Connect internal signals if not already (though usually better to do via editor or ready)
	# CheckBox signal is already exposed, but let's forward it
	if not checkbox.toggled.is_connected(_on_checkbox_toggled):
		checkbox.toggled.connect(_on_checkbox_toggled)
		
	if not edit_button.pressed.is_connected(_on_edit_pressed):
		edit_button.pressed.connect(_on_edit_pressed)

func _on_checkbox_toggled(on: bool):
	toggled.emit(on)

func _on_edit_pressed():
	edit_requested.emit()
