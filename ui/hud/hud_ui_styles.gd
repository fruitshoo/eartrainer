class_name HUDUIStyles
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func setup_visual_style() -> void:
	var top_bar_panel: PanelContainer = panel.get_node_or_null("%TopBarPanel")
	if top_bar_panel:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = panel.TOPBAR_BG
		panel_style.border_color = panel.TOPBAR_BORDER
		panel_style.set_corner_radius_all(16)
		panel_style.border_width_left = 1
		panel_style.border_width_top = 1
		panel_style.border_width_right = 1
		panel_style.border_width_bottom = 1
		panel_style.shadow_color = ThemeColors.APP_SHADOW
		panel_style.shadow_size = 6
		top_bar_panel.add_theme_stylebox_override("panel", panel_style)

	if panel.bpm_label:
		panel.bpm_label.add_theme_color_override("font_color", ThemeColors.APP_TEXT_MUTED)
		panel.bpm_label.add_theme_font_size_override("font_size", 12)
	if panel.chord_context_label:
		panel.chord_context_label.add_theme_color_override("font_color", panel.PILL_TEXT)
		panel.chord_context_label.add_theme_font_size_override("font_size", 13)
	if panel.key_button:
		panel.key_button.add_theme_font_size_override("font_size", 13)
	if panel.bpm_spin_box:
		panel.bpm_spin_box.add_theme_font_size_override("font_size", 13)
		var line_edit: LineEdit = panel.bpm_spin_box.get_line_edit()
		if line_edit:
			line_edit.add_theme_font_size_override("font_size", 13)
			line_edit.add_theme_color_override("font_color", panel.PILL_TEXT)

	var icon_buttons: Array[Button] = [
		panel.play_button,
		panel.stop_button,
		panel.record_button,
		panel.metronome_button,
		panel.sequencer_button,
		panel.trainer_button,
		panel.settings_button
	]
	for btn in icon_buttons:
		apply_pill_button_style(btn, true)
	apply_pill_button_style(panel.key_button, false)

func apply_pill_button_style(button: Button, compact: bool) -> void:
	if button == null:
		return
	var is_icon_only := button.text.strip_edges().is_empty()
	var radius: int = 10 if compact else 12
	var horizontal: int = 6 if compact else 9
	var vertical: int = 3 if compact else 4
	if not is_icon_only:
		horizontal -= 1
	button.add_theme_stylebox_override("normal", build_pill_style(panel.PILL_BG, panel.PILL_BORDER, radius, horizontal, vertical, 2))
	button.add_theme_stylebox_override("hover", build_pill_style(panel.PILL_BG_HOVER, panel.PILL_BORDER, radius, horizontal, vertical, 2))
	button.add_theme_stylebox_override("pressed", build_pill_style(panel.PILL_BG_PRESSED, panel.PILL_BORDER, radius, horizontal, vertical, 1))
	button.add_theme_stylebox_override("focus", build_pill_style(panel.PILL_BG_HOVER, ThemeColors.APP_ACCENT_GOLD, radius, horizontal, vertical, 2))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", panel.PILL_TEXT)
	button.add_theme_color_override("font_hover_color", panel.PILL_TEXT)
	button.add_theme_color_override("font_pressed_color", panel.PILL_TEXT)
	button.add_theme_color_override("icon_normal_color", panel.PILL_TEXT)
	button.add_theme_color_override("icon_hover_color", panel.PILL_TEXT)
	button.add_theme_color_override("icon_pressed_color", panel.PILL_TEXT)

func build_pill_style(fill_color: Color, border_color: Color, radius: int, margin_x: int, margin_y: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_corner_radius_all(radius)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = margin_x
	style.content_margin_top = margin_y
	style.content_margin_right = margin_x
	style.content_margin_bottom = margin_y
	style.shadow_color = ThemeColors.APP_SHADOW
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 1)
	return style

func update_workspace_buttons() -> void:
	if panel.sequencer_button:
		apply_workspace_button_state(panel.sequencer_button, panel._workspace_mode == 0)
	if panel.trainer_button:
		apply_workspace_button_state(panel.trainer_button, panel._workspace_mode == 1)

func apply_workspace_button_state(button: Button, is_active: bool) -> void:
	if button == null:
		return
	if is_active:
		button.add_theme_stylebox_override("normal", build_pill_style(panel.PILL_BG_ACTIVE, panel.PILL_BORDER_ACTIVE, 12, 9, 4, 2))
		button.add_theme_stylebox_override("hover", build_pill_style(panel.PILL_BG_ACTIVE.lightened(0.03), panel.PILL_BORDER_ACTIVE, 12, 9, 4, 2))
		button.add_theme_stylebox_override("pressed", build_pill_style(panel.PILL_BG_ACTIVE.darkened(0.03), panel.PILL_BORDER_ACTIVE, 12, 9, 4, 1))
		button.add_theme_stylebox_override("focus", build_pill_style(panel.PILL_BG_ACTIVE.lightened(0.03), ThemeColors.APP_ACCENT_GOLD, 12, 9, 4, 2))
		button.add_theme_color_override("font_color", panel.PILL_TEXT)
		button.add_theme_color_override("font_hover_color", panel.PILL_TEXT)
		button.add_theme_color_override("font_pressed_color", panel.PILL_TEXT)
	else:
		apply_pill_button_style(button, true)

func update_metronome_visual() -> void:
	if panel.metronome_button:
		panel.metronome_button.set_pressed_no_signal(GameManager.is_metronome_enabled)
		if GameManager.is_metronome_enabled:
			panel.metronome_button.modulate = Color.WHITE
			panel.metronome_button.add_theme_stylebox_override("normal", build_pill_style(panel.PILL_BG_ACTIVE, panel.PILL_BORDER_ACTIVE, 10, 6, 3, 2))
			panel.metronome_button.add_theme_stylebox_override("hover", build_pill_style(panel.PILL_BG_ACTIVE.lightened(0.03), panel.PILL_BORDER_ACTIVE, 10, 6, 3, 2))
			panel.metronome_button.add_theme_stylebox_override("pressed", build_pill_style(panel.PILL_BG_ACTIVE.darkened(0.03), panel.PILL_BORDER_ACTIVE, 10, 6, 3, 1))
		else:
			panel.metronome_button.modulate = Color.WHITE
			apply_pill_button_style(panel.metronome_button, true)

func set_ui_scale(value: float) -> void:
	if not panel.is_node_ready():
		await panel.ready

	var top_bar = panel.get_node_or_null("%TopBarPanel")
	if top_bar:
		if not top_bar.resized.is_connected(panel._update_pivot):
			top_bar.resized.connect(panel._update_pivot)

		if not is_equal_approx(top_bar.scale.x, value):
			top_bar.scale = Vector2(value, value)
			update_pivot()
			GameLogger.info("HUD set_ui_scale applying: %s (Size: %s)" % [value, top_bar.size])

func update_pivot() -> void:
	var top_bar = panel.get_node_or_null("%TopBarPanel")
	if top_bar:
		top_bar.pivot_offset = Vector2(top_bar.size.x / 2.0, 0)
