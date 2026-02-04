extends HBoxContainer

signal toggled(on: bool)
signal manage_requested() # Renamed from import/edit

@onready var checkbox: CheckBox = %CheckBox
@onready var edit_button: Button = %EditButton
@onready var spacer: Control = %Spacer

var manage_button: Button

func _ready() -> void:
	# Dynamically create Manage Button
	manage_button = Button.new()
	manage_button.text = "📂" # Folder Icon for Manage
	manage_button.tooltip_text = "Manage Examples"
	manage_button.flat = true
	manage_button.custom_minimum_size = Vector2(32, 0)
	manage_button.pressed.connect(_on_manage_pressed)
	add_child(manage_button)
	
	# Hide existing Edit Button (User Request)
	edit_button.visible = false
	move_child(manage_button, edit_button.get_index())

func setup(text: String, is_checked: bool, show_manage: bool = false):
	if not is_node_ready(): await ready
	
	checkbox.text = text
	checkbox.button_pressed = is_checked
	
	edit_button.visible = false # Always hide edit
	manage_button.visible = show_manage
	
	if not checkbox.toggled.is_connected(_on_checkbox_toggled):
		checkbox.toggled.connect(_on_checkbox_toggled)

func _on_checkbox_toggled(on: bool):
	toggled.emit(on)

func _on_manage_pressed():
	manage_requested.emit()
