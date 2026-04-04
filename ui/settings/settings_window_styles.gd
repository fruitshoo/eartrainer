class_name SettingsWindowStyles
extends RefCounted


func apply_dark_control_theme(window, root: Control) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is Label:
			child.add_theme_color_override(
				"font_color",
				window.PANEL_TEXT if child.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else window.PANEL_TEXT_MUTED
			)
		elif child is CheckBox:
			child.add_theme_color_override("font_color", window.PANEL_TEXT)
			child.add_theme_color_override("font_hover_color", window.PANEL_TEXT)
			child.add_theme_color_override("font_pressed_color", window.PANEL_TEXT)
		elif child is OptionButton or child is Button:
			apply_dark_button_style(window, child)
		elif child is LineEdit:
			child.add_theme_color_override("font_color", window.PANEL_TEXT)
			child.add_theme_color_override("font_placeholder_color", ThemeColors.APP_TEXT_HINT)
		elif child is SpinBox:
			var spin_box: SpinBox = child
			spin_box.add_theme_color_override("font_color", window.PANEL_TEXT)
			var line_edit: LineEdit = spin_box.get_line_edit()
			if line_edit:
				line_edit.add_theme_color_override("font_color", window.PANEL_TEXT)
				line_edit.add_theme_color_override("font_placeholder_color", ThemeColors.APP_TEXT_HINT)
		if child is Control:
			apply_dark_control_theme(window, child)


func apply_dark_button_style(window, button: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = window.PANEL_INPUT_BG
	style.border_color = window.PANEL_INPUT_BORDER
	style.set_corner_radius_all(12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6

	var hover = style.duplicate()
	hover.bg_color = window.PANEL_INPUT_BG_HOVER

	var pressed = style.duplicate()
	pressed.bg_color = window.PANEL_INPUT_BG.darkened(0.06)

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", window.PANEL_TEXT)
	button.add_theme_color_override("font_hover_color", window.PANEL_TEXT)
	button.add_theme_color_override("font_pressed_color", window.PANEL_TEXT)
	button.add_theme_color_override("font_focus_color", window.PANEL_TEXT)
	button.add_theme_color_override("icon_normal_color", window.PANEL_TEXT)
	button.add_theme_color_override("icon_hover_color", window.PANEL_TEXT)
	button.add_theme_color_override("icon_pressed_color", window.PANEL_TEXT)

	if button is OptionButton:
		var option_button: OptionButton = button
		option_button.add_theme_color_override("modulate_arrow", window.PANEL_TEXT)
		var popup: PopupMenu = option_button.get_popup()
		if popup:
			var popup_panel := StyleBoxFlat.new()
			popup_panel.bg_color = ThemeColors.APP_POPUP_BG
			popup_panel.border_color = window.PANEL_INPUT_BORDER
			popup_panel.set_corner_radius_all(12)
			popup_panel.border_width_left = 1
			popup_panel.border_width_top = 1
			popup_panel.border_width_right = 1
			popup_panel.border_width_bottom = 1

			var popup_hover := StyleBoxFlat.new()
			popup_hover.bg_color = window.PANEL_INPUT_BG_HOVER
			popup_hover.set_corner_radius_all(8)

			popup.add_theme_stylebox_override("panel", popup_panel)
			popup.add_theme_stylebox_override("hover", popup_hover)
			popup.add_theme_color_override("font_color", window.PANEL_TEXT)
			popup.add_theme_color_override("font_hover_color", window.PANEL_TEXT)
			popup.add_theme_color_override("font_disabled_color", ThemeColors.APP_TEXT_HINT)
