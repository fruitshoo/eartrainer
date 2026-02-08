# pie_menu.gd
class_name PieMenu
extends Control

signal chord_type_selected(type: String)
signal chord_type_hovered(type: String)
signal chord_type_unhovered
signal closed

const RADIUS := 80.0
const BUTTON_SIZE := Vector2(48, 48)
const CHORD_TYPES = ["M", "m", "7", "M7", "m7", "5"]

var _theme: Theme
var _buttons: Array[Button] = []
var _target_pos: Vector2

func _ready() -> void:
	# Load default theme
	_theme = load("res://ui/resources/main_theme.tres")
	theme = _theme
	
	# Click outside to close
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background dim (Covers full screen)
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.1) # Very subtle dim
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close()
	)
	add_child(bg)
	
	# Container for buttons
	var container = Control.new()
	container.name = "ButtonContainer"
	add_child(container)
	
	for i in range(CHORD_TYPES.size()):
		var type = CHORD_TYPES[i]
		var btn = Button.new()
		btn.text = type
		btn.custom_minimum_size = BUTTON_SIZE
		btn.pivot_offset = BUTTON_SIZE / 2
		btn.focus_mode = Control.FOCUS_NONE
		
		# Position calculation
		var angle = (i * PI * 2 / CHORD_TYPES.size()) - (PI / 2)
		var offset = Vector2(cos(angle), sin(angle)) * RADIUS
		btn.position = offset - (BUTTON_SIZE / 2)
		
		btn.pressed.connect(func():
			chord_type_selected.emit(type)
			_close()
		)
		
		btn.mouse_entered.connect(func():
			chord_type_hovered.emit(type)
		)
		
		btn.mouse_exited.connect(func():
			chord_type_unhovered.emit()
		)
		
		container.add_child(btn)
		_buttons.append(btn)
		
	# Animation
	container.scale = Vector2(0, 0) # Trigger scale animation
	
func setup(screen_pos: Vector2) -> void:
	_target_pos = screen_pos
	# Position the whole control or just the container
	var container = $ButtonContainer
	container.position = _target_pos
	
	# Pop-in animation
	container.scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "scale", Vector2.ONE, 0.5)
	
func _close():
	var container = $ButtonContainer
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(container, "scale", Vector2.ZERO, 0.2)
	tween.finished.connect(func():
		closed.emit()
		queue_free()
	)
