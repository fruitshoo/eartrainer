class_name MainUI
extends CanvasLayer

## MainUI: HUD와 SequenceUI만 관리하는 기본 UI 레이어
## SettingsUI, EarTrainerUI는 독립 CanvasLayer로 main.tscn에서 직접 관리

@onready var game_ui_container: Control = %GameUIContainer
@onready var hud: Control = game_ui_container.get_node("HUD")
@onready var sequence_ui: Control = game_ui_container.get_node("SequenceUI")
@onready var settings_window: SettingsWindow = %SettingsWindow
@onready var library_window: LibraryWindow = %LibraryWindow
@onready var side_panel: SidePanel = %SidePanel

func _ready() -> void:
	add_to_group("main_ui")
	EventBus.request_toggle_settings.connect(_on_request_toggle_settings)
	EventBus.request_toggle_library.connect(_on_request_toggle_library)
	EventBus.request_show_side_panel_tab.connect(_on_side_panel_requested)
	
	GameManager.ui_scale_changed.connect(_on_ui_scale_changed)
	get_tree().get_root().size_changed.connect(_update_ui_scale)
	
	call_deferred("_update_ui_scale")

func _on_ui_scale_changed(_value: float) -> void:
	_update_ui_scale()

func _update_ui_scale() -> void:
	var scale_val = GameManager.ui_scale
	
	if hud and hud.has_method("set_ui_scale"):
		GameLogger.info("MainUI calling HUD set_ui_scale: %s" % scale_val)
		hud.set_ui_scale(scale_val)
		
	if sequence_ui and sequence_ui.has_method("set_ui_scale"):
		sequence_ui.set_ui_scale(scale_val)
		
	# Apply to Side Panels
	if settings_window and settings_window.has_method("set_ui_scale"):
		settings_window.set_ui_scale(scale_val)
	if library_window and library_window.has_method("set_ui_scale"):
		library_window.set_ui_scale(scale_val)
	if side_panel and side_panel.has_method("set_ui_scale"):
		side_panel.set_ui_scale(scale_val)

func _on_request_toggle_settings() -> void:
	if settings_window.is_open:
		settings_window.close()
	else:
		_close_all_side_panels()
		settings_window.open()

func _on_request_toggle_library() -> void:
	if library_window.is_open:
		library_window.close()
	else:
		_close_all_side_panels()
		library_window.open()

func _on_side_panel_requested(_tab_idx: int) -> void:
	if side_panel.is_open:
		side_panel.close()
	else:
		_close_all_side_panels()
		side_panel.open()

func _close_all_side_panels() -> void:
	if settings_window.is_open: settings_window.close()
	if library_window.is_open: library_window.close()
	if side_panel.is_open: side_panel.close()
