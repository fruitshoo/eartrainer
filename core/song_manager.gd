class_name SongManager
extends Node

# ============================================================
# CONSTANTS
# ============================================================
const SAVE_PATH_SONGS = "user://songs.json"

# ============================================================
# SIGNALS
# ============================================================
signal songs_updated # List changed
signal song_loaded(song_data: Dictionary)

# ============================================================
# PUBLIC API
# ============================================================
func save_song(title: String) -> bool:
	var song_data = ProgressionManager.serialize().duplicate(true)
	song_data["title"] = title
	song_data["timestamp"] = Time.get_unix_time_from_system()
	song_data["bpm"] = GameManager.bpm
	
	var songs = _load_songs_safe()
	
	# Overwrite if exists
	var found = false
	for i in range(songs.size()):
		if songs[i].get("title") == title:
			songs[i] = song_data
			found = true
			break
	
	if not found:
		songs.append(song_data)
		
	return _save_json(SAVE_PATH_SONGS, songs)

func load_song(title: String) -> void:
	var songs = _load_songs_safe()
	var target_song = {}
	for s in songs:
		if s.get("title") == title:
			target_song = s
			break
			
	if target_song.is_empty():
		print("[SongManager] Song not found: ", title)
		return
		
	_apply_song_state(target_song)

func get_song_list() -> Array[Dictionary]:
	return _load_songs_safe()

func delete_song(title: String) -> void:
	var songs = _load_songs_safe()
	var new_list: Array[Dictionary] = []
	for s in songs:
		if s.get("title") != title:
			new_list.append(s)
			
	if _save_json(SAVE_PATH_SONGS, new_list):
		songs_updated.emit()

# ============================================================
# PRIVATE HELPERS
# ============================================================
func _load_songs_safe() -> Array[Dictionary]:
	if not FileAccess.file_exists(SAVE_PATH_SONGS):
		return []
		
	var file = FileAccess.open(SAVE_PATH_SONGS, FileAccess.READ)
	if not file: return []
	
	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) == OK:
		if json.data is Array:
			var typed_list: Array[Dictionary] = []
			for item in json.data:
				if item is Dictionary:
					typed_list.append(item)
			return typed_list
			
	return []

func _save_json(path: String, data: Variant) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		songs_updated.emit()
		return true
	return false

func _apply_song_state(data: Dictionary) -> void:
	# 1. Global Settings
	GameManager.bpm = int(data.get("bpm", 120))
	GameManager.current_key = int(data.get("key", 0))
	GameManager.current_mode = int(data.get("mode", 0))
	EventBus.game_settings_changed.emit()
	
	# 2. Progression + Melody
	if _is_full_sequence_snapshot(data):
		ProgressionManager.deserialize(data)
		ProgressionManager.force_refresh_ui()
	else:
		_apply_legacy_song_state(data)
	
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("sync_from_progression"):
		melody_manager.sync_from_progression()
	
	song_loaded.emit(data)

func _is_full_sequence_snapshot(data: Dictionary) -> bool:
	return data.has("bar_densities") or data.has("melody_events") or data.has("loop_start") or data.has("playback_mode")

func _apply_legacy_song_state(data: Dictionary) -> void:
	var new_bar_count = int(data.get("bar_count", 4))
	var new_beats = int(data.get("beats_per_bar", 4))
	
	ProgressionManager.update_settings(new_bar_count)
	ProgressionManager.set_time_signature(new_beats)
	
	var saved_slots = data.get("slots", [])
	if saved_slots is Array:
		for i in range(min(saved_slots.size(), ProgressionManager.slots.size())):
			var slot_data = saved_slots[i]
			if slot_data is Dictionary:
				ProgressionManager.slots[i] = slot_data.duplicate(true)
		
		for i in range(saved_slots.size(), ProgressionManager.slots.size()):
			ProgressionManager.slots[i] = null
	
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager and melody_manager.has_method("import_recorded_notes"):
		melody_manager.import_recorded_notes(data.get("melody", []))
	else:
		ProgressionManager.replace_all_melody_events({})
	
	ProgressionManager.force_refresh_ui()
