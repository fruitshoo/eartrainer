extends CanvasLayer

@onready var close_button: Button = %CloseButton

func _ready() -> void:
	EventBus.request_toggle_help.connect(toggle_visibility)
	close_button.pressed.connect(func(): visible = false)
	visible = false

func toggle_visibility() -> void:
	visible = !visible

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()
