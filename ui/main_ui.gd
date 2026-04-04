class_name MainUI
extends CanvasLayer

enum WorkspaceMode {SEQUENCER, TRAINER}

## MainUI: HUD와 SequenceUI만 관리하는 기본 UI 레이어
## SettingsUI, EarTrainerUI는 독립 CanvasLayer로 main.tscn에서 직접 관리

@onready var game_ui_container: Control = %GameUIContainer
@onready var hud: Control = game_ui_container.get_node("HUD")
@onready var sequence_ui: Control = game_ui_container.get_node("SequenceUI")
@onready var settings_window: SettingsWindow = %SettingsWindow
@onready var library_window: LibraryWindow = %LibraryWindow
@onready var side_panel: SidePanel = %SidePanel

var _workspace_mode: int = WorkspaceMode.SEQUENCER

func _ready() -> void:
	add_to_group("main_ui")
	EventBus.request_toggle_settings.connect(_on_request_toggle_settings)
	EventBus.request_toggle_library.connect(_on_request_toggle_library)
	EventBus.request_show_side_panel_tab.connect(_on_side_panel_requested)
	EventBus.request_set_workspace_mode.connect(_on_request_set_workspace_mode)
	
	GameManager.ui_scale_changed.connect(_on_ui_scale_changed)
	get_tree().get_root().size_changed.connect(_update_ui_scale)
	
	call_deferred("_update_ui_scale")
	call_deferred("_apply_workspace_mode", WorkspaceMode.SEQUENCER)

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
		_close_overlay_panels()
		settings_window.open()

func _on_request_toggle_library() -> void:
	if _workspace_mode != WorkspaceMode.SEQUENCER:
		_apply_workspace_mode(WorkspaceMode.SEQUENCER)
	if library_window.is_open:
		library_window.close()
	else:
		_close_overlay_panels()
		library_window.open()

func _on_side_panel_requested(_tab_idx: int) -> void:
	_apply_workspace_mode(WorkspaceMode.TRAINER)

func _on_request_set_workspace_mode(mode: int) -> void:
	_apply_workspace_mode(mode)

func _close_all_side_panels() -> void:
	if settings_window.is_open: settings_window.close()
	if library_window.is_open: library_window.close()
	if side_panel.is_open: side_panel.close()

func _close_overlay_panels() -> void:
	if settings_window.is_open:
		settings_window.close()
	if library_window.is_open:
		library_window.close()

func _apply_workspace_mode(mode: int) -> void:
	_workspace_mode = mode
	var trainer_mode := mode == WorkspaceMode.TRAINER

	if side_panel and side_panel.has_method("set_embedded_mode"):
		side_panel.set_embedded_mode(true)

	if trainer_mode:
		_close_overlay_panels()
		if sequence_ui:
			sequence_ui.visible = false
		if side_panel:
			side_panel.open()
	else:
		if sequence_ui:
			sequence_ui.visible = true
		if side_panel:
			side_panel.close()

	EventBus.workspace_mode_changed.emit(mode)
