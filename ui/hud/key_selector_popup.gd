class_name KeySelectorPopup
extends PopupPanel

const POPUP_BG := ThemeColors.APP_POPUP_BG
const POPUP_BORDER := ThemeColors.APP_POPUP_BORDER
const POPUP_TEXT := ThemeColors.APP_TEXT
const POPUP_TEXT_MUTED := ThemeColors.APP_TEXT_MUTED
const BUTTON_BG := ThemeColors.APP_BUTTON_BG
const BUTTON_BG_HOVER := ThemeColors.APP_BUTTON_BG_HOVER
const BUTTON_BG_ACTIVE := ThemeColors.APP_BUTTON_BG_ACTIVE
const BUTTON_BORDER := ThemeColors.APP_BUTTON_BORDER
const BUTTON_BORDER_ACTIVE := ThemeColors.APP_BUTTON_BORDER_ACTIVE

@onready var root_grid: GridContainer = %RootGrid
@onready var scale_option_button: OptionButton = %ScaleOptionButton
@onready var title_label: Label = %Label
@onready var context_label: Label = %ContextLabel

func _ready() -> void:
	_apply_visual_theme()
	_build_grid()
	_setup_scale_options()
	GameManager.settings_changed.connect(_update_visuals)
	
	# Update initially
	_update_visuals()

func _build_grid() -> void:
	for i in range(12):
		var btn = Button.new()
		# Text will be set in _update_visuals
		btn.custom_minimum_size = Vector2(40, 34)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_root_selected.bind(i))
		_apply_root_button_style(btn, false)
		root_grid.add_child(btn)

func _setup_scale_options() -> void:
	scale_option_button.clear()
	
	# Explicit order for better UX
	var ordered_modes = [
		MusicTheory.ScaleMode.MAJOR,
		MusicTheory.ScaleMode.MINOR,
		MusicTheory.ScaleMode.DORIAN,
		MusicTheory.ScaleMode.PHRYGIAN,
		MusicTheory.ScaleMode.LYDIAN,
		MusicTheory.ScaleMode.MIXOLYDIAN,
		MusicTheory.ScaleMode.LOCRIAN,
		MusicTheory.ScaleMode.MAJOR_PENTATONIC,
		MusicTheory.ScaleMode.MINOR_PENTATONIC
	]
	
	for scale_mode in ordered_modes:
		var data = MusicTheory.SCALE_DATA.get(scale_mode)
		if data:
			scale_option_button.add_item(data["name"], scale_mode)
			
	scale_option_button.item_selected.connect(_on_scale_selected)
	_apply_option_button_theme()

func _on_root_selected(root_idx: int) -> void:
	GameManager.current_key = root_idx
	_update_visuals()

func _on_scale_selected(index: int) -> void:
	var mode_id = scale_option_button.get_item_id(index)
	GameManager.current_mode = mode_id as MusicTheory.ScaleMode
	_update_visuals()

func _update_visuals() -> void:
	var mode_data = MusicTheory.SCALE_DATA.get(GameManager.current_mode, {"name": "Major"})
	if title_label:
		title_label.text = "Global Key & Mode"
	if context_label:
		context_label.text = "Current: %s %s" % [
			MusicTheory.get_note_name(GameManager.current_key, MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)),
			mode_data.get("name", "Major")
		]

	# Update Root Buttons Highlight & Text
	var current_key = GameManager.current_key
	var use_flats := MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	
	for i in range(root_grid.get_child_count()):
		var btn = root_grid.get_child(i) as Button
		btn.text = MusicTheory.get_note_name(i, use_flats)
		_apply_root_button_style(btn, i == current_key)
			
	# Update OptionButton Selection (Sync if changed externally)
	var current_mode_id = GameManager.current_mode
	var idx = scale_option_button.get_item_index(current_mode_id)
	if idx != -1 and scale_option_button.selected != idx:
		scale_option_button.select(idx)

func popup_centered_under_control(control: Control) -> void:
	# Calculate position
	var rect = control.get_global_rect()
	var target_pos = rect.position
	target_pos.y += rect.size.y + 5 # Below
	target_pos.x += rect.size.x / 2.0 - size.x / 2.0 # Centered horizontally
	
	self.position = Vector2i(target_pos)
	self.popup()
	
	# Animate content (MarginContainer is the first child)
	var content = get_child(0) if get_child_count() > 0 else null
	if content:
		content.modulate.a = 0.0
		content.scale = Vector2(0.95, 0.95)
		content.pivot_offset = content.size / 2.0
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(true)
		tween.tween_property(content, "modulate:a", 1.0, 0.15)
		tween.tween_property(content, "scale", Vector2.ONE, 0.2)

func _apply_visual_theme() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = POPUP_BG
	panel.border_color = POPUP_BORDER
	panel.set_corner_radius_all(16)
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.shadow_color = ThemeColors.APP_SHADOW
	panel.shadow_size = 20
	add_theme_stylebox_override("panel", panel)
	title_label.add_theme_color_override("font_color", POPUP_TEXT)
	context_label.add_theme_color_override("font_color", POPUP_TEXT_MUTED)

func _apply_root_button_style(button: Button, is_active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_BG_ACTIVE if is_active else BUTTON_BG
	normal.border_color = BUTTON_BORDER_ACTIVE if is_active else BUTTON_BORDER
	normal.set_corner_radius_all(11)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	var hover := normal.duplicate()
	if not is_active:
		hover.bg_color = BUTTON_BG_HOVER
	var pressed := hover.duplicate()
	pressed.bg_color = (BUTTON_BG_ACTIVE if is_active else BUTTON_BG_HOVER).darkened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", POPUP_TEXT)
	button.add_theme_color_override("font_hover_color", POPUP_TEXT)
	button.add_theme_color_override("font_pressed_color", POPUP_TEXT)
	button.modulate = Color.WHITE

func _apply_option_button_theme() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_BG
	normal.border_color = BUTTON_BORDER
	normal.set_corner_radius_all(12)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.content_margin_left = 12
	normal.content_margin_top = 7
	normal.content_margin_right = 12
	normal.content_margin_bottom = 7
	var hover := normal.duplicate()
	hover.bg_color = BUTTON_BG_HOVER
	var pressed := normal.duplicate()
	pressed.bg_color = BUTTON_BG_HOVER.darkened(0.08)
	scale_option_button.add_theme_stylebox_override("normal", normal)
	scale_option_button.add_theme_stylebox_override("hover", hover)
	scale_option_button.add_theme_stylebox_override("pressed", pressed)
	scale_option_button.add_theme_stylebox_override("focus", hover)
	scale_option_button.add_theme_color_override("font_color", POPUP_TEXT)
	scale_option_button.add_theme_color_override("font_hover_color", POPUP_TEXT)
	scale_option_button.add_theme_color_override("font_pressed_color", POPUP_TEXT)
	scale_option_button.add_theme_color_override("font_focus_color", POPUP_TEXT)
	scale_option_button.add_theme_color_override("modulate_arrow", POPUP_TEXT)
	var popup := scale_option_button.get_popup()
	if popup:
		var popup_panel := StyleBoxFlat.new()
		popup_panel.bg_color = ThemeColors.APP_POPUP_BG
		popup_panel.border_color = POPUP_BORDER
		popup_panel.set_corner_radius_all(12)
		popup_panel.border_width_left = 1
		popup_panel.border_width_top = 1
		popup_panel.border_width_right = 1
		popup_panel.border_width_bottom = 1
		var popup_hover := StyleBoxFlat.new()
		popup_hover.bg_color = BUTTON_BG_HOVER
		popup_hover.set_corner_radius_all(8)
		popup.add_theme_stylebox_override("panel", popup_panel)
		popup.add_theme_stylebox_override("hover", popup_hover)
		popup.add_theme_color_override("font_color", POPUP_TEXT)
		popup.add_theme_color_override("font_hover_color", POPUP_TEXT)
		popup.add_theme_color_override("font_disabled_color", ThemeColors.APP_TEXT_HINT)
		popup.add_theme_color_override("font_separator_color", POPUP_TEXT_MUTED)
		popup.add_theme_color_override("font_accelerator_color", POPUP_TEXT_MUTED)
