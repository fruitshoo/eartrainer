class_name PresetItem
extends PanelContainer

signal load_requested(preset_name: String)
signal delete_requested(preset_name: String)
signal item_clicked(preset_name: String)
signal set_default_requested(preset_name: String, is_default: bool)
signal reorder_requested(from_idx: int, to_idx: int)

const CARD_BG := ThemeColors.APP_PANEL_BG_SOFT
const CARD_BG_HOVER := ThemeColors.APP_BUTTON_BG_HOVER
const CARD_BG_SELECTED := ThemeColors.APP_PANEL_BG_ALT
const CARD_BORDER := ThemeColors.APP_BORDER
const CARD_BORDER_SELECTED := ThemeColors.APP_BUTTON_BORDER_ACTIVE
const TEXT_PRIMARY := ThemeColors.APP_TEXT
const TEXT_SECONDARY := ThemeColors.APP_TEXT_MUTED
const ICON_MUTED := ThemeColors.APP_TEXT_MUTED
const DELETE_ACCENT := Color(1.0, 0.58, 0.58, 0.92)
const DEFAULT_ACCENT := Color(1.0, 0.88, 0.46, 0.96)

@onready var name_label: Label = %NameLabel
@onready var details_label: Label = %DetailsLabel
@onready var load_button: Button = %LoadButton
@onready var delete_button: Button = %DeleteButton
@onready var default_button: Button = %DefaultButton

var preset_name: String = ""
var item_index: int = -1
var is_selected: bool = false
var is_default: bool = false
var _is_hovered: bool = false

func _init() -> void:
	# Ensure internal buttons don't steal focus
	# These will be initialized in _ready, but setting parent focus_mode is a good safety
	focus_mode = Control.FOCUS_NONE

func setup(data: Dictionary, index: int) -> void:
	preset_name = data.get("name", "Untitled")
	item_index = index
	name_label.text = preset_name
	tooltip_text = preset_name # [New] Show full name on hover
	name_label.tooltip_text = preset_name
	
	# Details
	var key_idx = int(data.get("key", 0)) # [Fix] Was 'key_note', actual save uses 'key'
	var mode_idx = int(data.get("mode", 0))
	var bar_count = data.get("bar_count", 4)
	
	var user_flats = MusicTheory.should_use_flats(key_idx, mode_idx)
	var key_str = MusicTheory.get_note_name(key_idx, user_flats)
	var mode_str = "Major" if mode_idx == MusicTheory.ScaleMode.MAJOR else "Minor"
	
	details_label.text = "%s %s · %d Bars" % [key_str, mode_str, bar_count]
	
	# Update Default status visual
	_update_default_visual()

func _ready() -> void:
	theme = load("res://ui/resources/main_theme.tres")
	_apply_card_theme()
	_apply_action_button_theme(load_button)
	_apply_action_button_theme(default_button)
	_apply_action_button_theme(delete_button, DELETE_ACCENT)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	details_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	
	# [Style] Small Icon Buttons (Ultra-Compact Horizontal Row - V4.5 Polish)
	load_button.icon = preload("res://assets/icons/play.svg")
	load_button.text = ""
	load_button.expand_icon = true
	load_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_button.custom_minimum_size = Vector2(32, 32)
	
	delete_button.text = "✖"
	delete_button.custom_minimum_size = Vector2(32, 32)
	delete_button.tooltip_text = "Delete"
	delete_button.modulate = Color.WHITE
	# Bold cross to match Play icon weight
	delete_button.add_theme_font_size_override("font_size", 14)
	
	load_button.pressed.connect(func(): load_requested.emit(preset_name))
	delete_button.pressed.connect(func(): delete_requested.emit(preset_name))
	default_button.toggled.connect(_on_default_toggled)
	
	load_button.focus_mode = Control.FOCUS_NONE
	delete_button.focus_mode = Control.FOCUS_NONE
	default_button.focus_mode = Control.FOCUS_NONE
	
	# Input Handling for Selection
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_style()

func set_is_default(val: bool) -> void:
	is_default = val
	_update_default_visual()

func _update_default_visual() -> void:
	if default_button:
		default_button.set_pressed_no_signal(is_default)
		# Star Icon (Reverted)
		default_button.text = "★" if is_default else "☆"
		var star_color: Color = DEFAULT_ACCENT if is_default else ICON_MUTED
		default_button.modulate = star_color
		default_button.add_theme_color_override("font_color", star_color)
		default_button.add_theme_color_override("font_hover_color", star_color)
		default_button.add_theme_color_override("font_pressed_color", star_color)

func _on_default_toggled(toggled: bool) -> void:
	set_default_requested.emit(preset_name, toggled)

func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_style()

# --- Drag & Drop Implementation ---
func _get_drag_data(at_position: Vector2) -> Variant:
	# Preview
	var preview = Label.new()
	preview.text = preset_name
	set_drag_preview(preview)
	
	return {"index": item_index, "name": preset_name}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Can drop if dragging a preset item and it's not self
	return data is Dictionary and data.has("index") and data["index"] != item_index

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var from_idx = data["index"]
	var to_idx = item_index
	reorder_requested.emit(from_idx, to_idx)

func _update_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG_SELECTED if is_selected else (CARD_BG_HOVER if _is_hovered else CARD_BG)
	style.border_color = CARD_BORDER_SELECTED if is_selected else CARD_BORDER
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	details_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	self_modulate = Color.WHITE

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		item_clicked.emit(preset_name)

# [Optional] Hover effects
func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_style()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_style()

func _apply_card_theme() -> void:
	_update_style()

func _apply_action_button_theme(button: Button, accent: Color = ICON_MUTED) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = ThemeColors.APP_BUTTON_BG
	normal.border_color = ThemeColors.APP_BUTTON_BORDER
	normal.set_corner_radius_all(9)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	var hover := normal.duplicate()
	hover.bg_color = ThemeColors.APP_BUTTON_BG_HOVER
	var pressed := normal.duplicate()
	pressed.bg_color = ThemeColors.APP_BUTTON_BG_PRESSED
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", accent)
	button.add_theme_color_override("icon_pressed_color", accent)
