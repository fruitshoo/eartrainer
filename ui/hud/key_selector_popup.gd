class_name KeySelectorPopup
extends PopupPanel

@onready var root_grid: GridContainer = %RootGrid
@onready var major_button: Button = %MajorButton
@onready var minor_button: Button = %MinorButton

var _roots = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

func _ready() -> void:
	_build_grid()
	
	# Connect Mode Buttons
	major_button.pressed.connect(_on_major_pressed)
	minor_button.pressed.connect(_on_minor_pressed)
	
	# Update initially
	_update_visuals()

func _build_grid() -> void:
	for i in range(12):
		var btn = Button.new()
		btn.text = _roots[i]
		btn.custom_minimum_size = Vector2(30, 30)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_root_selected.bind(i))
		root_grid.add_child(btn)

func _on_root_selected(root_idx: int) -> void:
	GameManager.current_key = root_idx
	_update_visuals()

func _on_major_pressed() -> void:
	GameManager.current_mode = MusicTheory.ScaleMode.MAJOR
	_update_visuals()
	
func _on_minor_pressed() -> void:
	GameManager.current_mode = MusicTheory.ScaleMode.MINOR
	_update_visuals()

func _update_visuals() -> void:
	# Update Root Buttons Highlight
	var current_key = GameManager.current_key
	for i in range(root_grid.get_child_count()):
		var btn = root_grid.get_child(i) as Button
		if i == current_key:
			btn.modulate = Color(1.0, 0.8, 0.2) # Gold Highlight
		else:
			btn.modulate = Color.WHITE
			
	# Update Mode Buttons State
	var is_major = (GameManager.current_mode == MusicTheory.ScaleMode.MAJOR)
	major_button.set_pressed_no_signal(is_major)
	minor_button.set_pressed_no_signal(not is_major)
	
	# Toggle button logic visual
	major_button.modulate = Color(1.0, 0.8, 0.2) if is_major else Color.WHITE
	minor_button.modulate = Color(1.0, 0.8, 0.2) if not is_major else Color.WHITE

func popup_centered_under_control(control: Control) -> void:
	# Calculate position
	var rect = control.get_global_rect()
	var pos = rect.position
	pos.y += rect.size.y + 5 # Below
	pos.x += rect.size.x / 2.0 - size.x / 2.0 # Centered horizontally
	
	# Clamp to viewport? PopupPanel usually handles some, but explicitly setting position works.
	self.position = Vector2i(pos)
	self.popup()
