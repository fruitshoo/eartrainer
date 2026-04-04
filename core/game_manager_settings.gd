class_name GameManagerSettings
extends RefCounted

const SAVE_PATH_SETTINGS := "user://game_settings.json"

var manager

func _init(p_manager) -> void:
	manager = p_manager

func save_settings() -> void:
	var data = {
		"current_key": manager.current_key,
		"current_mode": manager.current_mode,
		"current_notation_mode": manager.current_notation_mode,
		"bpm": manager.bpm,
		"show_note_labels": manager.show_note_labels,
		"highlight_root": manager.highlight_root,
		"highlight_chord": manager.highlight_chord,
		"highlight_scale": manager.highlight_scale,
		"is_metronome_enabled": manager.is_metronome_enabled,
		"focus_range": manager.focus_range,
		"camera_deadzone": manager.camera_deadzone,
		"is_rhythm_mode_enabled": manager.is_rhythm_mode_enabled,
		"default_preset_name": manager.default_preset_name,
		"current_theme_name": manager.current_theme_name,
		"ui_scale": manager.ui_scale,
		"volume_settings": get_volume_settings()
	}

	var file = FileAccess.open(SAVE_PATH_SETTINGS, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[GameManager] Settings saved.")

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH_SETTINGS):
		manager.is_settings_loaded = true
		manager.settings_loaded.emit()
		return

	var file = FileAccess.open(SAVE_PATH_SETTINGS, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(text)
		if error == OK:
			var data = json.data
			if data is Dictionary:
				deserialize_settings(data)
				print("[GameManager] Settings loaded.")

	manager.is_settings_loaded = true
	manager.settings_loaded.emit()
	manager.settings_changed.emit()

func deserialize_settings(data: Dictionary) -> void:
	manager.current_key = int(data.get("current_key", 0))
	manager.current_mode = int(data.get("current_mode", MusicTheory.ScaleMode.MAJOR)) as MusicTheory.ScaleMode
	manager.current_notation_mode = int(data.get("current_notation_mode", manager.NotationMode.CDE))

	if data.has("current_notation"):
		var old_notation = int(data.get("current_notation"))
		match old_notation:
			0:
				manager.current_notation_mode = manager.NotationMode.CDE
			1:
				manager.current_notation_mode = manager.NotationMode.DOREMI
			2:
				manager.current_notation_mode = manager.NotationMode.CDE
	elif data.has("show_notation_cde"):
		if data.get("show_notation_degree", false):
			manager.current_notation_mode = manager.NotationMode.DEGREE
		elif data.get("show_notation_doremi", false):
			manager.current_notation_mode = manager.NotationMode.DOREMI
		else:
			manager.current_notation_mode = manager.NotationMode.CDE

	manager.bpm = int(data.get("bpm", 120))
	manager.show_note_labels = data.get("show_note_labels", true)
	manager.highlight_root = data.get("highlight_root", true)
	manager.highlight_chord = data.get("highlight_chord", true)
	manager.highlight_scale = data.get("highlight_scale", true)
	manager.is_metronome_enabled = data.get("is_metronome_enabled", true)
	manager.focus_range = int(data.get("focus_range", 3))
	manager.camera_deadzone = float(data.get("camera_deadzone", 4.0))
	manager.ui_scale = float(data.get("ui_scale", 1.0))
	manager.is_rhythm_mode_enabled = data.get("is_rhythm_mode_enabled", false)
	manager.default_preset_name = data.get("default_preset_name", "")

	var loaded_theme = data.get("current_theme_name", "Default")
	if loaded_theme == "Pastel":
		manager.current_theme_name = "Default"
	else:
		manager.current_theme_name = loaded_theme

	var vol_settings = data.get("volume_settings", {})
	if not vol_settings.is_empty():
		apply_volume_settings(vol_settings)

func get_volume_settings() -> Dictionary:
	var settings = {}
	settings["Master"] = get_bus_volume("Master")
	settings["Chord"] = get_bus_volume("Chord")
	settings["Melody"] = get_bus_volume("Melody")
	settings["SFX"] = get_bus_volume("SFX")
	return settings

func get_bus_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func apply_volume_settings(settings: Dictionary) -> void:
	for bus_name in settings:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx != -1:
			var linear_vol = float(settings[bus_name])
			AudioServer.set_bus_volume_db(idx, linear_to_db(linear_vol))
			AudioServer.set_bus_mute(idx, linear_vol < 0.01)

func setup_runtime_nodes() -> void:
	manager.call_deferred("load_settings")

	if not manager.has_node("MelodyManager"):
		var melody_manager = MelodyManager.new()
		melody_manager.name = "MelodyManager"
		manager.add_child(melody_manager)
		melody_manager.visual_note_on.connect(manager._on_melody_visual_on)
		melody_manager.visual_note_off.connect(manager._on_melody_visual_off)

	EventBus.visual_note_on.connect(manager._on_melody_visual_on)
	EventBus.visual_note_off.connect(manager._on_melody_visual_off)

	if not manager.has_node("SongManager"):
		var song_manager = SongManager.new()
		song_manager.name = "SongManager"
		manager.add_child(song_manager)

	if not manager.has_node("RiffManager"):
		var riff_manager = RiffManager.new()
		riff_manager.name = "RiffManager"
		manager.add_child(riff_manager)
