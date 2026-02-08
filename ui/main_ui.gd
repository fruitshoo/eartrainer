class_name MainUI
extends CanvasLayer

## MainUI: HUD와 SequenceUI만 관리하는 기본 UI 레이어
## SettingsUI, EarTrainerUI는 독립 CanvasLayer로 main.tscn에서 직접 관리

@onready var game_ui_container: Control = %GameUIContainer
@onready var hud: Control = game_ui_container.get_node("HUD")
@onready var sequence_ui: Control = game_ui_container.get_node("SequenceUI")
@onready var settings_window: Control = %SettingsWindow
@onready var library_window: Control = %LibraryWindow
@onready var side_panel: Control = %SidePanel

func _ready() -> void:
	add_to_group("main_ui")
	EventBus.request_toggle_settings.connect(_on_request_toggle_settings)
	EventBus.request_toggle_library.connect(_on_request_toggle_library)
	EventBus.request_show_side_panel_tab.connect(_on_side_panel_requested)

func _on_request_toggle_settings() -> void:
	if settings_window.get("is_open"):
		settings_window.close()
	else:
		_close_all_side_panels()
		settings_window.open()

func _on_request_toggle_library() -> void:
	if library_window.get("is_open"):
		library_window.close()
	else:
		_close_all_side_panels()
		library_window.open()

func _on_side_panel_requested(_tab_idx: int) -> void:
	if side_panel.get("is_open"):
		side_panel.close()
	else:
		_close_all_side_panels()
		side_panel.open()

func _close_all_side_panels() -> void:
	if settings_window.get("is_open"): settings_window.close()
	if library_window.get("is_open"): library_window.close()
	if side_panel.get("is_open"): side_panel.close()
