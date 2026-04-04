class_name SettingsWindowControls
extends RefCounted


func setup_volume_controls(window, master: HSlider, chord: HSlider, melody: HSlider, sfx: HSlider) -> void:
	connect_volume_slider(window, "Master", "Master", master)
	connect_volume_slider(window, "Chord", "Chord", chord)
	connect_volume_slider(window, "Melody", "Melody", melody)
	connect_volume_slider(window, "SFX", "SFX", sfx)


func connect_volume_slider(window, key: String, bus_name: String, slider: HSlider) -> void:
	window._controls[key] = slider
	if not slider.value_changed.is_connected(window._on_volume_changed):
		slider.value_changed.connect(window._on_volume_changed.bind(bus_name))


func on_volume_changed(_window, val: float, bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(val))
		AudioServer.set_bus_mute(idx, val < 0.01)


func setup_notation_controls(window, opt: OptionButton) -> void:
	window._controls["notation_mode"] = opt
	if not opt.item_selected.is_connected(window._on_notation_changed):
		opt.item_selected.connect(window._on_notation_changed)


func on_notation_changed(_window, idx: int) -> void:
	GameManager.current_notation_mode = idx
	GameManager.save_settings()


func setup_display_controls(window, show_lbl: CheckBox, hl_root: CheckBox, hl_chord: CheckBox, hl_scale: CheckBox, ui_scale: HSlider, ui_lbl: Label) -> void:
	connect_checkbox(window, "show_labels", show_lbl, func(v): GameManager.show_note_labels = v; GameManager.save_settings())
	connect_checkbox(window, "highlight_root", hl_root, func(v): GameManager.highlight_root = v; GameManager.save_settings())
	connect_checkbox(window, "highlight_chord", hl_chord, func(v): GameManager.highlight_chord = v; GameManager.save_settings())
	connect_checkbox(window, "highlight_scale", hl_scale, func(v): GameManager.highlight_scale = v; GameManager.save_settings())

	window._controls["ui_scale"] = ui_scale
	window._controls["ui_scale_lbl"] = ui_lbl
	if not ui_scale.value_changed.is_connected(window._on_ui_scale_changed):
		ui_scale.value_changed.connect(window._on_ui_scale_changed.bind(ui_lbl))


func on_ui_scale_changed(_window, v: float, lbl: Label) -> void:
	GameManager.ui_scale = v
	lbl.text = "%.2f" % v
	GameManager.save_settings()


func connect_checkbox(window, key: String, cb: CheckBox, callback: Callable) -> void:
	window._controls[key] = cb
	if not cb.toggled.is_connected(callback):
		cb.toggled.connect(callback)


func setup_camera_controls(window, str_focus: OptionButton, f_lbl: Label, f_min: Button, f_plus: Button, d_lbl: Label, d_min: Button, d_plus: Button) -> void:
	window._controls["string_focus"] = str_focus
	if not str_focus.item_selected.is_connected(window._on_string_focus_changed):
		str_focus.item_selected.connect(window._on_string_focus_changed.bind(str_focus))

	window._controls["focus_range_lbl"] = f_lbl
	if not f_min.pressed.is_connected(window._update_focus_range):
		f_min.pressed.connect(window._update_focus_range.bind(-1))
		f_plus.pressed.connect(window._update_focus_range.bind(1))

	window._controls["deadzone_lbl"] = d_lbl
	if not d_min.pressed.is_connected(window._update_deadzone):
		d_min.pressed.connect(window._update_deadzone.bind(-1))
		d_plus.pressed.connect(window._update_deadzone.bind(1))


func on_string_focus_changed(_window, idx: int, opt: OptionButton) -> void:
	GameManager.string_focus_range = opt.get_item_id(idx)
	GameManager.save_settings()


func update_focus_range(window, delta: int) -> void:
	GameManager.focus_range = clampi(GameManager.focus_range + delta, 1, 12)
	update_value_label(window, "focus_range_lbl", str(GameManager.focus_range))
	GameManager.save_settings()


func update_deadzone(window, direction: int) -> void:
	GameManager.camera_deadzone = clampf(GameManager.camera_deadzone + (direction * 0.5), 0.0, 10.0)
	update_value_label(window, "deadzone_lbl", str(GameManager.camera_deadzone))
	GameManager.save_settings()


func update_value_label(window, key: String, text: String) -> void:
	if window._controls.has(key):
		window._controls[key].text = text


func sync_settings_from_game_manager(window) -> void:
	if window._controls.has("notation_mode"):
		window._controls["notation_mode"].select(GameManager.current_notation_mode)

	if window._controls.has("show_labels"):
		window._controls["show_labels"].set_pressed_no_signal(GameManager.show_note_labels)
	if window._controls.has("highlight_root"):
		window._controls["highlight_root"].set_pressed_no_signal(GameManager.highlight_root)
	if window._controls.has("highlight_chord"):
		window._controls["highlight_chord"].set_pressed_no_signal(GameManager.highlight_chord)
	if window._controls.has("highlight_scale"):
		window._controls["highlight_scale"].set_pressed_no_signal(GameManager.highlight_scale)

	if window._controls.has("ui_scale"):
		window._controls["ui_scale"].set_value_no_signal(GameManager.ui_scale)
	update_value_label(window, "ui_scale_lbl", "%.2f" % GameManager.ui_scale)

	if window._controls.has("string_focus"):
		var opt: OptionButton = window._controls["string_focus"]
		var current_range := GameManager.string_focus_range
		for i in range(opt.item_count):
			if opt.get_item_id(i) == current_range:
				opt.select(i)
				break

	update_value_label(window, "focus_range_lbl", str(GameManager.focus_range))
	update_value_label(window, "deadzone_lbl", str(GameManager.camera_deadzone))

	for key in ["Master", "Chord", "Melody", "SFX"]:
		if window._controls.has(key):
			var idx := AudioServer.get_bus_index(key)
			if idx != -1:
				window._controls[key].value = db_to_linear(AudioServer.get_bus_volume_db(idx))
