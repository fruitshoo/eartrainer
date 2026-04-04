# library_window.gd
# 전용 라이브러리 창 - 프리셋(진행) 및 곡(Song) 목록 관리
class_name LibraryWindow
extends BaseSidePanel

const LIBRARY_WINDOW_STYLES := preload("res://ui/library/library_window_styles.gd")
const LIBRARY_WINDOW_BEHAVIOR := preload("res://ui/library/library_window_behavior.gd")

const PANEL_TEXT := ThemeColors.APP_TEXT
const PANEL_TEXT_MUTED := ThemeColors.APP_TEXT_MUTED
const PANEL_INPUT_BG := ThemeColors.APP_INPUT_BG
const PANEL_INPUT_BG_HOVER := ThemeColors.APP_INPUT_BG_HOVER
const PANEL_INPUT_BORDER := ThemeColors.APP_INPUT_BORDER

enum LibraryTabMode {PRESETS, SONGS}

signal load_requested(item_name: String, mode: LibraryTabMode)

var preset_item_scene: PackedScene = preload("res://ui/sequence/library_panel/preset_item.tscn")
var _main_theme: Theme = preload("res://ui/resources/main_theme.tres")

var presets_tab_btn: Button
var songs_tab_btn: Button
var preset_list_container: VBoxContainer
var save_btn: Button
var name_input: LineEdit

var current_mode: LibraryTabMode = LibraryTabMode.PRESETS
var selected_item: String = ""

var _library_style_helper: LibraryWindowStyles = LIBRARY_WINDOW_STYLES.new()
var _behavior_helper: LibraryWindowBehavior = LIBRARY_WINDOW_BEHAVIOR.new()


func open() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_update_position(false)
	super.open()
	_refresh_list()


func close() -> void:
	super.close()


func set_open(do_open: bool) -> void:
	super.set_open(do_open)


func _build_content() -> void:
	var main_container = %MainContainer
	presets_tab_btn = %PresetsTabBtn
	songs_tab_btn = %SongsTabBtn
	preset_list_container = %PresetListContainer
	name_input = %NameInput
	save_btn = %SaveBtn

	if main_container:
		remove_child(main_container)
		_content_container.add_child(main_container)
		main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_apply_dark_control_theme(main_container)

	presets_tab_btn.toggled.connect(_on_mode_toggled.bind(LibraryTabMode.PRESETS))
	songs_tab_btn.toggled.connect(_on_mode_toggled.bind(LibraryTabMode.SONGS))
	save_btn.pressed.connect(_on_save_pressed)

	theme = _main_theme
	_refresh_list()


func _apply_dark_control_theme(root: Control) -> void:
	_library_style_helper.apply_dark_control_theme(self, root)


func _apply_dark_button_style(button: Control) -> void:
	_library_style_helper.apply_dark_button_style(self, button)


func _on_mode_toggled(toggled: bool, mode: LibraryTabMode) -> void:
	_behavior_helper.on_mode_toggled(self, toggled, mode)


func _refresh_list() -> void:
	_behavior_helper.refresh_list(self)


func _on_save_pressed() -> void:
	_behavior_helper.on_save_pressed(self)


func _on_load_requested(item_name: String) -> void:
	_behavior_helper.on_load_requested(self, item_name)


func _on_delete_requested(item_name: String) -> void:
	_behavior_helper.on_delete_requested(self, item_name)


func _on_item_clicked(item_name: String) -> void:
	_behavior_helper.on_item_clicked(self, item_name)


func _update_selection() -> void:
	_behavior_helper.update_selection(self)


func _on_set_default(item_name: String, is_default: bool) -> void:
	_behavior_helper.on_set_default(self, item_name, is_default)


func _on_reorder(from_idx: int, to_idx: int) -> void:
	_behavior_helper.on_reorder(self, from_idx, to_idx)
