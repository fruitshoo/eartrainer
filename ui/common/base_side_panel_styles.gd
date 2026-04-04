class_name BaseSidePanelStyles
extends RefCounted


func build_base_ui(panel) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel._visual_root = MarginContainer.new()
	panel._visual_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel._visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel._visual_root)
	panel._visual_root.resized.connect(panel._update_scale_pivot)

	panel._panel_container = PanelContainer.new()
	panel._panel_container.clip_contents = true
	panel._panel_container.add_theme_stylebox_override("panel", get_base_style_box("panel_bg"))
	panel._panel_container.add_theme_color_override("font_color", ThemeColors.APP_TEXT)
	panel._panel_container.add_theme_color_override("font_hover_color", ThemeColors.APP_TEXT)
	panel._panel_container.add_theme_color_override("font_pressed_color", ThemeColors.APP_TEXT)
	panel._panel_container.add_theme_color_override("font_focus_color", ThemeColors.APP_TEXT)
	panel._visual_root.add_child(panel._panel_container)
	panel._refresh_layout(false)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", panel.MARGIN_OUTER)
	content_margin.add_theme_constant_override("margin_right", panel.MARGIN_OUTER)
	content_margin.add_theme_constant_override("margin_top", panel.MARGIN_OUTER)
	content_margin.add_theme_constant_override("margin_bottom", panel.MARGIN_OUTER)
	panel._panel_container.add_child(content_margin)

	panel._content_container = VBoxContainer.new()
	panel._content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel._content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel._content_container.add_theme_constant_override("separation", panel.SPACING_SECTION)
	content_margin.add_child(panel._content_container)


func get_base_style_box(type: String) -> StyleBox:
	match type:
		"empty":
			return StyleBoxEmpty.new()
		"panel_bg":
			var sb := StyleBoxFlat.new()
			sb.bg_color = ThemeColors.APP_PANEL_BG
			sb.corner_radius_top_left = 24
			sb.corner_radius_top_right = 24
			sb.corner_radius_bottom_right = 24
			sb.corner_radius_bottom_left = 24
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = ThemeColors.APP_BORDER
			sb.shadow_color = ThemeColors.APP_SHADOW
			sb.shadow_size = 8
			return sb
	return StyleBoxEmpty.new()
