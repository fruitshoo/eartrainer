# pie_menu.gd
class_name PieMenu
extends Control

signal chord_type_selected(type: String)
signal chord_type_hovered(type: String)
signal chord_type_unhovered
signal closed

const BUTTON_SIZE := Vector2(50, 30)
const CHORD_TYPES = ["auto", "M", "m", "7", "M7", "m7", "5", "dim", "sus4", "clear"]
const LABELS := {
	"auto": "Auto",
	"M": "M",
	"m": "m",
	"7": "7",
	"M7": "M7",
	"m7": "m7",
	"5": "5",
	"dim": "dim",
	"sus4": "sus4",
	"clear": "Clear"
}

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
	var container = PanelContainer.new()
	container.name = "ButtonContainer"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeColors.APP_POPUP_BG
	panel_style.border_color = ThemeColors.APP_POPUP_BORDER
	panel_style.set_corner_radius_all(12)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.shadow_color = ThemeColors.APP_SHADOW
	panel_style.shadow_size = 3
	container.add_theme_stylebox_override("panel", panel_style)
	add_child(container)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	container.add_child(margin)

	var flow = HFlowContainer.new()
	flow.name = "Buttons"
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	margin.add_child(flow)

	for i in range(CHORD_TYPES.size()):
		var type = CHORD_TYPES[i]
		var btn = Button.new()
		btn.text = str(LABELS.get(type, type))
		btn.custom_minimum_size = BUTTON_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
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
		
		flow.add_child(btn)
		_buttons.append(btn)
		
	# Animation
	container.scale = Vector2(0.92, 0.92)
	container.modulate.a = 0.0
	
func setup(screen_pos: Vector2) -> void:
	_target_pos = screen_pos
	var container: Control = $ButtonContainer
	await get_tree().process_frame
	var viewport_rect := get_viewport_rect()
	var container_size := container.size
	var desired := _target_pos + Vector2(14, -18)
	if desired.x + container_size.x > viewport_rect.size.x - 12.0:
		desired.x = viewport_rect.size.x - container_size.x - 12.0
	if desired.y + container_size.y > viewport_rect.size.y - 12.0:
		desired.y = viewport_rect.size.y - container_size.y - 12.0
	if desired.x < 12.0:
		desired.x = 12.0
	if desired.y < 12.0:
		desired.y = 12.0
	container.position = desired
	
	# Pop-in animation
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(container, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(container, "modulate:a", 1.0, 0.12)
	
func _close():
	var container: Control = $ButtonContainer
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(container, "scale", Vector2(0.96, 0.96), 0.1)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 0.1)
	tween.finished.connect(func():
		closed.emit()
		queue_free()
	)
