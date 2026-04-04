class_name HUDUIBehavior
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func setup_transport() -> void:
	if panel.play_button:
		panel.play_button.icon = panel.ICON_PLAY
		panel.play_button.pressed.connect(func(): EventBus.request_toggle_playback.emit())
		panel.play_button.focus_mode = Control.FOCUS_NONE

	if panel.stop_button:
		panel.stop_button.icon = panel.ICON_STOP
		panel.stop_button.pressed.connect(func(): EventBus.request_stop_playback.emit())
		panel.stop_button.focus_mode = Control.FOCUS_NONE

	if panel.record_button:
		panel.record_button.visible = false

	if panel.metronome_button:
		panel.metronome_button.icon = panel.ICON_METRONOME
		panel.metronome_button.button_pressed = GameManager.is_metronome_enabled
		panel.metronome_button.toggled.connect(func(toggled): GameManager.is_metronome_enabled = toggled)
		panel.metronome_button.focus_mode = Control.FOCUS_NONE

	if panel.bpm_spin_box:
		panel.bpm_spin_box.value = GameManager.bpm
		panel.bpm_spin_box.value_changed.connect(func(val): GameManager.bpm = int(val))
		panel.bpm_spin_box.add_theme_color_override("font_color", panel.PILL_TEXT)
		var le: LineEdit = panel.bpm_spin_box.get_line_edit()
		if le:
			le.focus_mode = Control.FOCUS_NONE
			le.mouse_filter = Control.MOUSE_FILTER_IGNORE
			le.add_theme_color_override("font_color", panel.PILL_TEXT)
			le.add_theme_color_override("font_placeholder_color", ThemeColors.APP_TEXT_HINT)

func setup_navigation() -> void:
	if panel.key_button:
		panel.key_button.pressed.connect(panel._on_key_button_pressed)
		panel.key_button.focus_mode = Control.FOCUS_NONE
		panel.key_button.tooltip_text = "Global key and mode"
	if panel.chord_context_label:
		panel.chord_context_label.tooltip_text = "Current harmonic context"

	if panel.settings_button:
		panel.settings_button.pressed.connect(func(): EventBus.request_toggle_settings.emit())
		panel.settings_button.focus_mode = Control.FOCUS_NONE

	if panel.sequencer_button:
		panel.sequencer_button.pressed.connect(func(): EventBus.request_set_workspace_mode.emit(0))
		panel.sequencer_button.focus_mode = Control.FOCUS_NONE

	if panel.trainer_button:
		panel.trainer_button.pressed.connect(func(): EventBus.request_set_workspace_mode.emit(1))
		panel.trainer_button.focus_mode = Control.FOCUS_NONE

func delayed_setup() -> void:
	await panel.get_tree().process_frame

	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager:
		if not melody_manager.recording_started.is_connected(panel._on_recording_started):
			melody_manager.recording_started.connect(panel._on_recording_started)
		if not melody_manager.recording_stopped.is_connected(panel._on_recording_stopped):
			melody_manager.recording_stopped.connect(panel._on_recording_stopped)

	panel._update_display()
	panel._update_metronome_visual()
	panel._on_workspace_mode_changed(panel._workspace_mode)
	panel.set_ui_scale(GameManager.ui_scale)

func on_workspace_mode_changed(mode: int) -> void:
	panel._workspace_mode = mode
	panel._update_workspace_buttons()

func update_display() -> void:
	panel._update_metronome_visual()
	if not panel.key_button:
		return

	var use_flats := MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var key_name := MusicTheory.get_note_name(GameManager.current_key, use_flats)
	var mode_name := str(MusicTheory.SCALE_DATA.get(GameManager.current_mode, {"name": "Major"}).get("name", "Major"))

	var chord_root: int = GameManager.current_chord_root
	var chord_type: String = GameManager.current_chord_type
	if EventBus.is_sequencer_playing and panel._current_sequencer_step >= 0:
		var slot_data = ProgressionManager.get_slot(panel._current_sequencer_step)
		if slot_data:
			chord_root = slot_data.root
			chord_type = slot_data.type

	var degree := MusicTheory.get_degree_numeral(chord_root, chord_type, GameManager.current_key)
	var key_mode_text := "%s %s" % [key_name, mode_name]
	var context_text: String = degree if not degree.is_empty() else "No chord"

	panel.key_button.pivot_offset = panel.key_button.size / 2.0
	if panel.chord_context_label:
		panel.chord_context_label.pivot_offset = panel.chord_context_label.size / 2.0

	if key_mode_text != panel._last_key_mode_text:
		panel.key_button.text = key_mode_text
		panel._last_key_mode_text = key_mode_text

	if panel.chord_context_label and context_text != panel._last_chord_context_text:
		panel.chord_context_label.text = context_text
		panel._animate_chord_change()
		panel._last_chord_context_text = context_text

func animate_chord_change() -> void:
	if panel._chord_tween and panel._chord_tween.is_running():
		panel._chord_tween.kill()

	panel._is_animating = true
	panel._chord_tween = panel.create_tween()
	panel._chord_tween.tween_property(panel.chord_context_label if panel.chord_context_label else panel.key_button, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel._chord_tween.tween_property(panel.chord_context_label if panel.chord_context_label else panel.key_button, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	panel._chord_tween.finished.connect(func(): panel._is_animating = false)

func on_bar_changed(slot_index: int) -> void:
	panel._current_sequencer_step = slot_index
	panel._update_display()

func on_sequencer_playing_changed(is_playing: bool) -> void:
	if panel.play_button:
		panel.play_button.icon = panel.ICON_PAUSE if is_playing else panel.ICON_PLAY

func on_record_toggled(toggled: bool) -> void:
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager:
		if toggled:
			if not melody_manager.is_recording:
				melody_manager.start_recording()

			if not EventBus.is_sequencer_playing:
				var sequencer = panel.get_tree().get_first_node_in_group("sequencer")
				if sequencer and sequencer.has_method("start_with_count_in"):
					sequencer.start_with_count_in()
		else:
			if melody_manager.is_recording:
				melody_manager.stop_recording()

func on_request_toggle_recording() -> void:
	if panel.record_button:
		panel.record_button.button_pressed = not panel.record_button.button_pressed

func on_recording_started() -> void:
	if panel.record_button:
		panel.record_button.set_pressed_no_signal(true)
		panel.record_button.modulate = Color(1.0, 0.3, 0.3)

func on_recording_stopped() -> void:
	if panel.record_button:
		panel.record_button.set_pressed_no_signal(false)
		panel.record_button.modulate = Color.WHITE

func on_key_button_pressed() -> void:
	if not panel.key_selector_popup:
		return

	if panel.key_selector_popup.visible:
		panel.key_selector_popup.hide()
		return

	if Time.get_ticks_msec() - panel._popup_hide_timestamp < 500:
		return

	panel.key_selector_popup.popup_centered_under_control(panel.key_button)

func on_key_selector_popup_hide() -> void:
	panel._popup_hide_timestamp = Time.get_ticks_msec()
