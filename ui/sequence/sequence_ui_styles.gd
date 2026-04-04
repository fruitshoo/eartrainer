class_name SequenceUIStyles
extends RefCounted

const TOOLBAR_PILL_BG := ThemeColors.APP_BUTTON_BG
const TOOLBAR_PILL_BG_HOVER := ThemeColors.APP_BUTTON_BG_HOVER
const TOOLBAR_PILL_BG_PRESSED := ThemeColors.APP_BUTTON_BG_PRESSED
const TOOLBAR_PILL_BORDER := ThemeColors.APP_BUTTON_BORDER
const TOOLBAR_PILL_TEXT := ThemeColors.APP_TEXT

var panel

func _init(p_panel) -> void:
	panel = p_panel

func apply_soft_panel_styles() -> void:
	var main_panel: PanelContainer = panel.get_node_or_null("RootMargin/MainPanel")
	if main_panel:
		main_panel.add_theme_stylebox_override("panel", build_panel_style(
			ThemeColors.SEQUENCER_PANEL_BG,
			ThemeColors.APP_BORDER,
			14
		))
	var editor_panel: PanelContainer = panel.chord_editor_panel
	if editor_panel:
		editor_panel.add_theme_stylebox_override("panel", build_panel_style(
			ThemeColors.SEQUENCER_PANEL_BG_ALT,
			ThemeColors.APP_BORDER,
			12
		))

func build_panel_style(fill_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_corner_radius_all(radius)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = ThemeColors.APP_SHADOW
	style.shadow_size = 2
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func apply_toolbar_button_style(button: Button, compact: bool) -> void:
	if button == null:
		return
	var is_icon_only := button.text.strip_edges().is_empty()
	var radius: int = 10 if compact else 11
	var horizontal: int = 6 if compact else 9
	var vertical: int = 3 if compact else 4
	if not is_icon_only:
		horizontal -= 1
	button.add_theme_stylebox_override("normal", build_toolbar_pill_style(TOOLBAR_PILL_BG, TOOLBAR_PILL_BORDER, radius, horizontal, vertical, 2))
	button.add_theme_stylebox_override("hover", build_toolbar_pill_style(TOOLBAR_PILL_BG_HOVER, TOOLBAR_PILL_BORDER, radius, horizontal, vertical, 2))
	button.add_theme_stylebox_override("pressed", build_toolbar_pill_style(TOOLBAR_PILL_BG_PRESSED, TOOLBAR_PILL_BORDER, radius, horizontal, vertical, 1))
	button.add_theme_stylebox_override("focus", build_toolbar_pill_style(TOOLBAR_PILL_BG_HOVER, ThemeColors.APP_ACCENT_GOLD, radius, horizontal, vertical, 2))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("font_hover_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("font_pressed_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("icon_normal_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("icon_hover_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("icon_pressed_color", TOOLBAR_PILL_TEXT)

func apply_option_button_style(button: OptionButton) -> void:
	if button == null:
		return
	var normal := build_toolbar_pill_style(TOOLBAR_PILL_BG, TOOLBAR_PILL_BORDER, 11, 7, 3, 2)
	var hover := build_toolbar_pill_style(TOOLBAR_PILL_BG_HOVER, TOOLBAR_PILL_BORDER, 11, 7, 3, 2)
	var pressed := build_toolbar_pill_style(TOOLBAR_PILL_BG_PRESSED, TOOLBAR_PILL_BORDER, 11, 7, 3, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", build_toolbar_pill_style(TOOLBAR_PILL_BG_HOVER, ThemeColors.APP_ACCENT_GOLD, 11, 7, 3, 2))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("font_hover_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("font_pressed_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("font_focus_color", TOOLBAR_PILL_TEXT)
	button.add_theme_color_override("modulate_arrow", TOOLBAR_PILL_TEXT)

	var popup: PopupMenu = button.get_popup()
	if popup:
		var popup_panel := StyleBoxFlat.new()
		popup_panel.bg_color = ThemeColors.APP_POPUP_BG
		popup_panel.border_color = ThemeColors.APP_POPUP_BORDER
		popup_panel.set_corner_radius_all(12)
		popup_panel.border_width_left = 1
		popup_panel.border_width_top = 1
		popup_panel.border_width_right = 1
		popup_panel.border_width_bottom = 1
		var popup_hover := StyleBoxFlat.new()
		popup_hover.bg_color = TOOLBAR_PILL_BG_HOVER
		popup_hover.set_corner_radius_all(8)
		popup.add_theme_stylebox_override("panel", popup_panel)
		popup.add_theme_stylebox_override("hover", popup_hover)
		popup.add_theme_color_override("font_color", TOOLBAR_PILL_TEXT)
		popup.add_theme_color_override("font_hover_color", TOOLBAR_PILL_TEXT)
		popup.add_theme_color_override("font_disabled_color", ThemeColors.APP_TEXT_HINT)

func build_toolbar_pill_style(fill_color: Color, border_color: Color, radius: int, margin_x: int, margin_y: int, shadow_size: int) -> StyleBoxFlat:
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
