class_name SidePanelStyles
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func update_tile_style(btn: Button, color: Color, is_active: bool) -> void:
	if not btn:
		return

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	if is_active:
		style.bg_color = color
		style.border_color = color.darkened(0.2)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		style.bg_color = ThemeColors.APP_BUTTON_BG
		style.border_color = ThemeColors.APP_BUTTON_BORDER
		btn.add_theme_color_override("font_color", ThemeColors.APP_TEXT)
		btn.add_theme_color_override("font_hover_color", ThemeColors.APP_TEXT)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func setup_mode_button(btn: Button, text: String, mode_id: int, color: Color, pos_idx: int) -> void:
	if not btn:
		return

	btn.text = text
	btn.button_pressed = mode_id in QuizManager.active_modes
	btn.toggled.connect(func(on: bool):
		if panel.interval_controller:
			panel.interval_controller._on_et_mode_toggled(on, mode_id)
		update_mode_button_style(btn, color, on, pos_idx)
	)
	btn.add_theme_color_override("font_hover_color", ThemeColors.APP_TEXT)
	update_mode_button_style(btn, color, btn.button_pressed, pos_idx)

func update_mode_button_style(btn: Button, color: Color, is_active: bool, pos_idx: int) -> void:
	if not btn:
		return

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12 if pos_idx == 0 else 0
	style.corner_radius_bottom_left = 12 if pos_idx == 0 else 0
	style.corner_radius_top_right = 12 if pos_idx == 2 else 0
	style.corner_radius_bottom_right = 12 if pos_idx == 2 else 0
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1 if pos_idx == 2 else 0
	style.border_width_bottom = 1

	if is_active:
		style.bg_color = color.lightened(0.1)
		style.border_color = color.darkened(0.1)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		style.bg_color = ThemeColors.APP_BUTTON_BG
		style.border_color = ThemeColors.APP_BUTTON_BORDER
		btn.add_theme_color_override("font_color", ThemeColors.APP_TEXT_MUTED)
		btn.add_theme_color_override("font_hover_color", ThemeColors.APP_TEXT)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func setup_stage_button(btn: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20
	normal.bg_color = color.lightened(0.18)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = color.darkened(0.12)

	var hover := normal.duplicate()
	hover.bg_color = Color(color.r, color.g, color.b, 0.8)

	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", ThemeColors.APP_TEXT)
	btn.add_theme_color_override("font_hover_color", ThemeColors.APP_TEXT)
	btn.add_theme_color_override("font_pressed_color", ThemeColors.APP_TEXT)
