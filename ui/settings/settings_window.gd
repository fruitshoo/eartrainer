class_name SettingsWindow
extends BaseSidePanel

const SETTINGS_WINDOW_STYLES := preload("res://ui/settings/settings_window_styles.gd")
const SETTINGS_WINDOW_CONTROLS := preload("res://ui/settings/settings_window_controls.gd")

const PANEL_TEXT := ThemeColors.APP_TEXT
const PANEL_TEXT_MUTED := ThemeColors.APP_TEXT_MUTED
const PANEL_INPUT_BG := ThemeColors.APP_INPUT_BG
const PANEL_INPUT_BG_HOVER := ThemeColors.APP_INPUT_BG_HOVER
const PANEL_INPUT_BORDER := ThemeColors.APP_INPUT_BORDER

var _controls: Dictionary = {}
var _settings_style_helper: SettingsWindowStyles = SETTINGS_WINDOW_STYLES.new()
var _control_helper: SettingsWindowControls = SETTINGS_WINDOW_CONTROLS.new()


func _ready() -> void:
	super._ready()


func open() -> void:
	super.open()
	_sync_settings_from_game_manager()


func _build_content() -> void:
	var scroll = %ScrollContainer
	var master_vol = %MasterVol
	var chord_vol = %ChordVol
	var melody_vol = %MelodyVol
	var sfx_vol = %SFXVol
	var not_mode = %NotationMode
	var show_lbl = %ShowLabels
	var hl_root = %HighlightRoot
	var hl_chord = %HighlightChord
	var hl_scale = %HighlightScale
	var ui_scale = %UIScale
	var ui_scale_lbl = %UIScaleLbl
	var str_focus = %StringFocus
	var focus_lbl = %FocusRangeLbl
	var focus_min = %FocusRangeMinus
	var focus_plus = %FocusRangePlus
	var dead_lbl = %DeadzoneLbl
	var dead_min = %DeadzoneMinus
	var dead_plus = %DeadzonePlus

	remove_child(scroll)
	_content_container.add_child(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_dark_control_theme(scroll)
	var camera_title := scroll.get_node("Content/CameraSection/Label") as Label
	var deadzone_label := scroll.get_node("Content/CameraSection/GridContainer/LabelDeadzone") as Label
	var deadzone_row := scroll.get_node("Content/CameraSection/GridContainer/DeadzoneRow") as HBoxContainer
	camera_title.text = "Fretboard Focus"
	deadzone_label.visible = false
	deadzone_row.visible = false

	_setup_volume_controls(master_vol, chord_vol, melody_vol, sfx_vol)
	_setup_notation_controls(not_mode)
	_setup_display_controls(show_lbl, hl_root, hl_chord, hl_scale, ui_scale, ui_scale_lbl)
	_setup_camera_controls(str_focus, focus_lbl, focus_min, focus_plus, dead_lbl, dead_min, dead_plus)


func _apply_dark_control_theme(root: Control) -> void:
	_settings_style_helper.apply_dark_control_theme(self, root)


func _apply_dark_button_style(button: Control) -> void:
	_settings_style_helper.apply_dark_button_style(self, button)


func _setup_volume_controls(master: HSlider, chord: HSlider, melody: HSlider, sfx: HSlider) -> void:
	_control_helper.setup_volume_controls(self, master, chord, melody, sfx)


func _connect_volume_slider(key: String, bus_name: String, slider: HSlider) -> void:
	_control_helper.connect_volume_slider(self, key, bus_name, slider)


func _on_volume_changed(val: float, bus_name: String) -> void:
	_control_helper.on_volume_changed(self, val, bus_name)


func _setup_notation_controls(opt: OptionButton) -> void:
	_control_helper.setup_notation_controls(self, opt)


func _on_notation_changed(idx: int) -> void:
	_control_helper.on_notation_changed(self, idx)


func _setup_display_controls(show_lbl: CheckBox, hl_root: CheckBox, hl_chord: CheckBox, hl_scale: CheckBox, ui_scale: HSlider, ui_lbl: Label) -> void:
	_control_helper.setup_display_controls(self, show_lbl, hl_root, hl_chord, hl_scale, ui_scale, ui_lbl)


func _on_ui_scale_changed(v: float, lbl: Label) -> void:
	_control_helper.on_ui_scale_changed(self, v, lbl)


func _connect_checkbox(key: String, cb: CheckBox, callback: Callable) -> void:
	_control_helper.connect_checkbox(self, key, cb, callback)


func _setup_camera_controls(str_focus: OptionButton, f_lbl: Label, f_min: Button, f_plus: Button, d_lbl: Label, d_min: Button, d_plus: Button) -> void:
	_control_helper.setup_camera_controls(self, str_focus, f_lbl, f_min, f_plus, d_lbl, d_min, d_plus)


func _on_string_focus_changed(idx: int, opt: OptionButton) -> void:
	_control_helper.on_string_focus_changed(self, idx, opt)


func _update_focus_range(delta: int) -> void:
	_control_helper.update_focus_range(self, delta)


func _update_deadzone(dir: int) -> void:
	_control_helper.update_deadzone(self, dir)


func _update_value_label(key: String, text: String) -> void:
	_control_helper.update_value_label(self, key, text)


func _sync_settings_from_game_manager() -> void:
	_control_helper.sync_settings_from_game_manager(self)
