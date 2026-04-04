class_name SequenceUIControls
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func setup_controls() -> void:
	var clear_melody_button = panel.get_node_or_null("%ClearMelodyButton")
	if clear_melody_button:
		clear_melody_button.pressed.connect(panel._clear_melody)
		clear_melody_button.focus_mode = Control.FOCUS_NONE
		clear_melody_button.tooltip_text = "Clear All Melody (Shift+Del)"
		panel._apply_toolbar_button_style(clear_melody_button, true)

	panel.bar_count_spin_box.value_changed.connect(panel._on_bar_count_changed)
	panel.bar_count_spin_box.add_theme_font_size_override("font_size", 13)
	panel.bar_count_spin_box.add_theme_color_override("font_color", panel.TOOLBAR_PILL_TEXT)
	var line_edit: LineEdit = panel.bar_count_spin_box.get_line_edit()
	if line_edit:
		line_edit.focus_mode = Control.FOCUS_NONE
		line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_edit.add_theme_font_size_override("font_size", 13)
		line_edit.add_theme_color_override("font_color", panel.TOOLBAR_PILL_TEXT)
		line_edit.add_theme_color_override("font_placeholder_color", ThemeColors.APP_TEXT_HINT)

	if panel.split_bar_button:
		panel.split_bar_button.pressed.connect(panel._on_split_bar_pressed)
		panel.split_bar_button.focus_mode = Control.FOCUS_NONE
		panel._apply_toolbar_button_style(panel.split_bar_button, true)

	if panel.time_sig_button:
		panel.time_sig_button.pressed.connect(panel._on_time_sig_pressed)
		panel._apply_toolbar_button_style(panel.time_sig_button, false)
	_ensure_section_context_menu()

	if panel.copy_bar_button:
		panel.copy_bar_button.pressed.connect(panel._copy_selected_bar)
		panel.copy_bar_button.focus_mode = Control.FOCUS_NONE
		panel.copy_bar_button.tooltip_text = "Copy selected bar (Cmd/Ctrl+C)"
		panel._apply_toolbar_button_style(panel.copy_bar_button, true)

	if panel.paste_bar_button:
		panel.paste_bar_button.pressed.connect(panel._paste_to_selected_bar)
		panel.paste_bar_button.focus_mode = Control.FOCUS_NONE
		panel.paste_bar_button.tooltip_text = "Paste into selected bar (Cmd/Ctrl+V)"
		panel._apply_toolbar_button_style(panel.paste_bar_button, true)

	if panel.library_button:
		panel.library_button.pressed.connect(func(): EventBus.request_toggle_library.emit())
		panel.library_button.focus_mode = Control.FOCUS_NONE
		panel._apply_toolbar_button_style(panel.library_button, true)

	if panel.chord_editor_panel:
		panel._chord_type_buttons = {
			"auto": panel.get_node("%AutoTypeButton"),
			"M": panel.get_node("%TypeMButton"),
			"m": panel.get_node("%TypemButton"),
			"7": panel.get_node("%Type7Button"),
			"M7": panel.get_node("%TypeM7Button"),
			"m7": panel.get_node("%Typem7Button"),
			"5": panel.get_node("%Type5Button"),
			"dim": panel.get_node("%TypeDimButton"),
			"sus4": panel.get_node("%TypeSus4Button")
		}
		for type_name in panel.INLINE_CHORD_TYPES:
			var btn: Button = panel._chord_type_buttons.get(type_name)
			if btn:
				btn.pressed.connect(panel._apply_inline_chord_type.bind(type_name))
				btn.focus_mode = Control.FOCUS_NONE
				panel._apply_toolbar_button_style(btn, true)

		var auto_btn: Button = panel._chord_type_buttons.get("auto")
		if auto_btn:
			auto_btn.pressed.connect(panel._apply_auto_chord_type)
			auto_btn.focus_mode = Control.FOCUS_NONE
			panel._apply_toolbar_button_style(auto_btn, true)

		var clear_btn = panel.get_node_or_null("%ClearChordButton")
		if clear_btn:
			clear_btn.pressed.connect(panel._clear_selected_chord)
			clear_btn.focus_mode = Control.FOCUS_NONE
			panel._apply_toolbar_button_style(clear_btn, true)
		panel._update_chord_editor()

func sync_ui_from_manager() -> void:
	panel.bar_count_spin_box.set_value_no_signal(ProgressionManager.bar_count)
	panel._update_split_button_state()

	if panel.time_sig_button:
		panel.time_sig_button.text = "%d/4" % ProgressionManager.beats_per_bar

	update_bar_tools_state()
	panel._update_chord_editor()
	panel._refresh_all_melody_slots()

	var scroll_container = panel.get_node_or_null("%SequencerScroll")
	if scroll_container:
		var bars_per_system: int = panel._get_system_bar_count()
		var system_count: int = int(ceil(float(ProgressionManager.bar_count) / float(bars_per_system)))
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if system_count <= 2 else ScrollContainer.SCROLL_MODE_AUTO
		var target_height = panel._get_scroll_target_height()
		var current_height = scroll_container.custom_minimum_size.y
		if abs(current_height - target_height) > 1.0:
			var height_tween = panel.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			height_tween.tween_property(scroll_container, "custom_minimum_size:y", target_height, 0.25)
			if panel.slot_container:
				panel.slot_container.modulate.a = 0.0
			height_tween.parallel().tween_property(panel.slot_container, "modulate:a", 1.0, 0.25)

func update_bar_tools_state() -> void:
	var active_bar: int = panel._bar_clipboard_helper.get_copy_target_bar()
	var has_active_bar: bool = active_bar >= 0

	if panel.copy_bar_button:
		panel.copy_bar_button.disabled = not has_active_bar
	if panel.paste_bar_button:
		panel.paste_bar_button.disabled = not has_active_bar or not ProgressionManager.has_bar_clipboard()

func on_section_preset_selected(index: int) -> void:
	var active_bar: int = panel._get_active_bar_index()
	if active_bar < 0:
		update_bar_tools_state()
		return

	if index <= 0:
		ProgressionManager.clear_section_label(active_bar)
	else:
		ProgressionManager.set_section_label(active_bar, panel.SECTION_PRESET_LABELS[index])
	update_bar_tools_state()

func show_section_context_menu(bar_index: int, screen_position: Vector2) -> void:
	if bar_index < 0:
		return
	_ensure_section_context_menu()
	if panel._section_context_menu == null:
		return
	panel._section_context_bar_index = bar_index
	panel._section_context_menu.clear()
	panel._section_context_menu.add_item("Clear Section", 0)
	panel._section_context_menu.add_separator()
	for i in range(1, panel.SECTION_PRESET_LABELS.size()):
		panel._section_context_menu.add_item(panel.SECTION_PRESET_LABELS[i], i)
	panel._section_context_menu.position = screen_position
	panel._section_context_menu.popup()

func on_section_context_menu_id_pressed(id: int) -> void:
	var bar_index: int = panel._section_context_bar_index
	if bar_index < 0:
		return
	if id <= 0:
		ProgressionManager.clear_section_label(bar_index)
	else:
		ProgressionManager.set_section_label(bar_index, panel.SECTION_PRESET_LABELS[id])
	update_bar_tools_state()

func _ensure_section_context_menu() -> void:
	if panel._section_context_menu != null:
		return
	var popup := PopupMenu.new()
	popup.name = "SectionContextMenu"
	popup.id_pressed.connect(panel._on_section_context_menu_id_pressed)
	panel.add_child(popup)
	panel._section_context_menu = popup

func copy_selected_bar() -> void:
	panel._bar_clipboard_helper.copy_selected_bar()
	update_bar_tools_state()

func paste_to_selected_bar() -> void:
	panel._bar_clipboard_helper.paste_to_selected_bar()
	update_bar_tools_state()
