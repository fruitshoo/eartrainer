class_name SequenceUILayout
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func rebuild_slots() -> void:
	for child in panel.slot_container.get_children():
		child.queue_free()
	panel._slot_buttons.clear()
	panel._timeline_slots_by_bar.clear()
	panel._melody_slots_by_bar.clear()
	panel._melody_slot_lookup.clear()
	panel._active_melody_playhead_key = ""

	panel.slot_container.add_theme_constant_override("separation", panel._get_system_spacing())

	var total_bars: int = ProgressionManager.bar_count
	var slot_global_index: int = 0
	var bar_width: float = panel._get_bar_width()
	var chord_slot_height: float = panel._get_chord_slot_height()
	var melody_slot_height: float = panel._get_melody_slot_height()
	var row_spacing: int = panel._get_row_spacing()
	var compact_layout: bool = panel._use_compact_layout()

	var bars_per_system: int = panel._get_system_bar_count()
	for system_start in range(0, total_bars, bars_per_system):
		var system_end = min(system_start + bars_per_system, total_bars)
		var system_vbox := VBoxContainer.new()
		system_vbox.add_theme_constant_override("separation", row_spacing)
		system_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.slot_container.add_child(system_vbox)

		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", row_spacing + 2)
		header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		system_vbox.add_child(header_row)

		var timeline_row := HBoxContainer.new()
		timeline_row.add_theme_constant_override("separation", 0)
		timeline_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		system_vbox.add_child(timeline_row)

		var chord_row := HBoxContainer.new()
		chord_row.add_theme_constant_override("separation", row_spacing + 2)
		chord_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		system_vbox.add_child(chord_row)

		for current_bar_idx in range(system_start, system_end):
			var header_box := MarginContainer.new()
			header_box.custom_minimum_size = Vector2(bar_width, panel._get_header_row_height())
			header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header_box.add_theme_constant_override("margin_left", 2 if compact_layout else 3)
			header_box.add_theme_constant_override("margin_right", 2 if compact_layout else 3)
			header_row.add_child(header_box)

			var header_frame := PanelContainer.new()
			header_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header_frame.mouse_filter = Control.MOUSE_FILTER_PASS
			header_box.add_child(header_frame)

			var header_style := StyleBoxFlat.new()
			header_style.bg_color = Color(0, 0, 0, 0)
			header_style.border_width_bottom = 1
			header_style.border_color = Color(0.35, 0.28, 0.18, 0.08)
			header_style.content_margin_left = 3
			header_style.content_margin_right = 3
			header_style.content_margin_top = 0
			header_style.content_margin_bottom = 0

			var phrase_idx = int(floor(float(current_bar_idx) / 4.0)) + 1
			var section_label: String = ProgressionManager.get_section_label(current_bar_idx)
			var previous_section_label: String = ""
			if current_bar_idx > 0:
				previous_section_label = ProgressionManager.get_section_label(current_bar_idx - 1)
			var is_new_section_start: bool = not section_label.is_empty() and section_label != previous_section_label
			var header_label := Label.new()
			header_label.clip_text = true
			header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if is_new_section_start:
				header_style.bg_color = Color(0.95, 0.90, 0.80, 0.72)
				header_style.border_width_left = 3
				header_style.border_color = ThemeColors.APP_ACCENT_GOLD_SOFT
				header_frame.add_theme_stylebox_override("panel", header_style)
				header_label.text = section_label
				header_label.theme_type_variation = &"HeaderSmall"
				header_label.modulate = ThemeColors.APP_TEXT
				header_label.add_theme_font_size_override("font_size", 13 if compact_layout else 14)
				header_label.mouse_filter = Control.MOUSE_FILTER_STOP
				header_label.tooltip_text = "Right-click to change section label"
				header_label.gui_input.connect(_on_header_label_gui_input.bind(current_bar_idx))
				header_frame.add_child(header_label)
			elif current_bar_idx % 4 == 0:
				header_style.bg_color = Color(0.97, 0.94, 0.88, 0.45)
				header_style.border_width_left = 2
				header_style.border_color = Color(0.45, 0.34, 0.19, 0.18)
				header_frame.add_theme_stylebox_override("panel", header_style)
				header_label.text = "Phrase %d" % phrase_idx
				header_label.theme_type_variation = &"HeaderSmall"
				header_label.modulate = ThemeColors.APP_TEXT_MUTED
				header_label.add_theme_font_size_override("font_size", 12 if compact_layout else 13)
				header_label.mouse_filter = Control.MOUSE_FILTER_STOP
				header_label.tooltip_text = "Right-click to set section label"
				header_label.gui_input.connect(_on_header_label_gui_input.bind(current_bar_idx))
				header_frame.add_child(header_label)
			else:
				header_frame.add_theme_stylebox_override("panel", header_style)
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(bar_width, panel._get_header_row_height())
				header_frame.add_child(spacer)

			var density: int = ProgressionManager.bar_densities[current_bar_idx]
			var m_beats: int = ProgressionManager.beats_per_bar
			var m_subs: int = 2
			var total_m_slots: int = m_beats * m_subs
			var m_slot_width: float = bar_width / float(total_m_slots)
			var events: Dictionary = ProgressionManager.get_melody_events(current_bar_idx)

			var timeline_btn = panel.timeline_ruler_scene.instantiate()
			timeline_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			timeline_btn.custom_minimum_size = Vector2(bar_width, 18)
			timeline_row.add_child(timeline_btn)
			panel._timeline_slots_by_bar[current_bar_idx] = timeline_btn
			if timeline_btn.has_method("setup"):
				timeline_btn.setup(current_bar_idx, m_beats, m_subs)
			if timeline_btn.has_signal("beat_clicked"):
				timeline_btn.beat_clicked.connect(panel._on_timeline_beat_clicked)

			var chord_hbox := HBoxContainer.new()
			chord_hbox.add_theme_constant_override("separation", 4)
			chord_hbox.custom_minimum_size.x = bar_width
			chord_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chord_row.add_child(chord_hbox)

			for k in range(density):
				var slot_idx = slot_global_index
				slot_global_index += 1

				var btn = panel.slot_button_scene.instantiate()
				btn.focus_mode = Control.FOCUS_NONE
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.custom_minimum_size.y = chord_slot_height
				if btn.has_method("set_show_beat_strip"):
					btn.set_show_beat_strip(false)
				connect_slot_signals(btn)
				chord_hbox.add_child(btn)
				panel._slot_buttons.append(btn)

				if btn.has_method("setup"):
					btn.setup(slot_idx, ProgressionManager.beats_per_bar if density == 1 else 2)
				if btn.has_method("set_time_context"):
					btn.set_time_context(get_slot_time_context_label(slot_idx))
				if btn.has_method("set_bar_context"):
					btn.set_bar_context(current_bar_idx, k, density)

				var data = ProgressionManager.get_slot(slot_idx)
				if data and btn.has_method("update_info"):
					btn.update_info(data)

		if system_end < total_bars:
			var sep := Control.new()
			sep.custom_minimum_size.y = panel._get_system_spacing()
			panel.slot_container.add_child(sep)

	var sequencer = _get_sequencer()
	if sequencer:
		panel._update_timeline_playhead(sequencer.current_step, sequencer.current_beat, sequencer._sub_beat)
	panel.call_deferred("_update_loop_overlay")

func get_melody_slot_key(bar: int, beat: int, sub: int) -> String:
	return "%d_%d_%d" % [bar, beat, sub]

func get_slot_time_context_label(slot_idx: int) -> String:
	var bar_idx = ProgressionManager.get_bar_index_for_slot(slot_idx)
	if bar_idx < 0:
		return ""
	var start_slot = ProgressionManager.get_slot_index_for_bar(bar_idx)
	var density = max(1, ProgressionManager.bar_densities[bar_idx])
	var beats_per_slot = max(1, int(ProgressionManager.beats_per_bar / density))
	var slot_offset = slot_idx - start_slot
	var start_beat = (slot_offset * beats_per_slot) + 1
	var end_beat = start_beat + beats_per_slot - 1
	return "Bar %d · Beats %d-%d" % [bar_idx + 1, start_beat, end_beat]

func connect_slot_signals(btn: Control) -> void:
	if btn.has_signal("beat_clicked"):
		btn.beat_clicked.connect(panel._on_slot_beat_clicked)
	if btn.has_signal("slot_pressed"):
		btn.slot_pressed.connect(panel._on_slot_clicked)
	if btn.has_signal("right_clicked"):
		btn.right_clicked.connect(panel._on_slot_right_clicked)

	if EventBus.is_sequencer_playing:
		var sequencer = panel.get_tree().get_first_node_in_group("sequencer")
		if sequencer:
			panel.call_deferred("_highlight_playing", sequencer.current_step)

func _get_sequencer():
	return panel.get_node_or_null("%Sequencer")

func _on_header_label_gui_input(event: InputEvent, bar_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		panel._show_section_context_menu(bar_index, panel.get_global_mouse_position())
