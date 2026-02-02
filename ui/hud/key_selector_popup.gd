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
	var target_pos = rect.position
	target_pos.y += rect.size.y + 5 # Below
	target_pos.x += rect.size.x / 2.0 - size.x / 2.0 # Centered horizontally
	
	self.position = Vector2i(target_pos)
	self.popup()
	
	# Animate content (MarginContainer is the first child)
	var content = get_child(0) if get_child_count() > 0 else null
	if content:
		content.modulate.a = 0.0
		content.scale = Vector2(0.95, 0.95)
		content.pivot_offset = content.size / 2.0
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(true)
		tween.tween_property(content, "modulate:a", 1.0, 0.15)
		tween.tween_property(content, "scale", Vector2.ONE, 0.2)
