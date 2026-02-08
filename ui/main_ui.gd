class_name MainUI
extends CanvasLayer

## MainUI: HUD와 SequenceUI만 관리하는 기본 UI 레이어
## SettingsUI, EarTrainerUI는 독립 CanvasLayer로 main.tscn에서 직접 관리

@onready var game_ui_container: Control = %GameUIContainer
@onready var hud: Control = game_ui_container.get_node("HUD")
@onready var sequence_ui: Control = game_ui_container.get_node("SequenceUI")
@onready var settings_window: Control = %SettingsWindow
@onready var library_window := %LibraryWindow as LibraryWindow

func _ready() -> void:
	EventBus.request_toggle_settings.connect(_on_request_toggle_settings)
	EventBus.request_toggle_library.connect(_on_request_toggle_library)

func _on_request_toggle_settings() -> void:
	if settings_window.visible:
		settings_window.close()
	else:
		settings_window.open()

func _on_request_toggle_library() -> void:
	if library_window.visible:
		library_window.close()
	else:
		library_window.open()
