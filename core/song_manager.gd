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
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	var melody_data = []
	if melody_manager:
		melody_data = melody_manager.recorded_notes
		
	var song_data = {
		"title": title,
		"timestamp": Time.get_unix_time_from_system(),
		"bpm": GameManager.bpm,
		"key": GameManager.current_key,
		"mode": GameManager.current_mode,
		"bar_count": ProgressionManager.bar_count,
		"slots": ProgressionManager.slots,
		"melody": melody_data
	}
	
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
	
	# 2. Progression
	var new_bar_count = int(data.get("bar_count", 4))
	ProgressionManager.update_settings(new_bar_count)
	
	var saved_slots = data.get("slots", [])
	if saved_slots is Array:
		# Copy slot data
		for i in range(min(saved_slots.size(), ProgressionManager.slots.size())):
			var s = saved_slots[i]
			# Ensure dictionary format (convert if needed, but here we save direct dicts)
			if s is Dictionary:
				ProgressionManager.slots[i] = s.duplicate()
		
		# Reset others
		for i in range(saved_slots.size(), ProgressionManager.slots.size()):
			ProgressionManager.slots[i] = null
			
	ProgressionManager.force_refresh_ui()
	
	# 3. Melody
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager:
		melody_manager.clear_melody()
		var melody_data = data.get("melody", [])
		if melody_data is Array:
			# Type safety check
			for note in melody_data:
				if note is Dictionary:
					melody_manager.recorded_notes.append(note)
		print("[SongManager] Loaded melody with %d notes" % melody_manager.recorded_notes.size())
		
	song_loaded.emit(data)
