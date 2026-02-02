class_name RiffManager
extends Node

const SAVE_PATH = "user://riffs.json"

# Dictionary of Interval Semitones -> Array of Riff Dictionaries
# { 4: [{title: "My Riff", notes: [...]}, ...] }
var user_riffs: Dictionary = {} # interval -> list of riffs (Legacy name: user_interval_riffs)
var user_pitch_riffs: Dictionary = {} # pitch_class -> list of riffs
var playback_preferences: Dictionary = {} # { "interval_7": { "mode": "random" }, "pitch_0": { "mode": "single", "id": "..." } }

func _ready():
	_load_riffs()

func add_riff(key: int, riff_data: Dictionary, type: String = "interval") -> void:
	# Add timestamp/ID if needed
	riff_data["id"] = Time.get_unix_time_from_system()
	
	if type == "pitch":
		if not user_pitch_riffs.has(key):
			user_pitch_riffs[key] = []
		user_pitch_riffs[key].append(riff_data)
	else:
		if not user_riffs.has(key):
			user_riffs[key] = []
		user_riffs[key].append(riff_data)
		
	_save_riffs()

func delete_riff(key: int, riff_index: int, type: String = "interval") -> void:
	if type == "pitch":
		if user_pitch_riffs.has(key) and riff_index >= 0 and riff_index < user_pitch_riffs[key].size():
			user_pitch_riffs[key].remove_at(riff_index)
			_save_riffs()
	else:
		if user_riffs.has(key) and riff_index >= 0 and riff_index < user_riffs[key].size():
			user_riffs[key].remove_at(riff_index)
			_save_riffs()

func update_riff(key: int, riff_index: int, new_data: Dictionary, type: String = "interval") -> void:
	var target_dict = user_pitch_riffs if type == "pitch" else user_riffs
	
	if target_dict.has(key) and riff_index >= 0 and riff_index < target_dict[key].size():
		# Preserve ID if it exists, or ensure new one?
		# For now, just overwrite, but maybe keep original ID if useful later.
		var original = target_dict[key][riff_index]
		if original.has("id"):
			new_data["id"] = original["id"]
		else:
			new_data["id"] = Time.get_unix_time_from_system()
			
		target_dict[key][riff_index] = new_data
		_save_riffs()

func get_riffs_for_interval(interval: int) -> Array:
	return get_riffs(interval, "interval")

func get_riffs(key: int, type: String = "interval", mode: int = -1) -> Array:
	if type == "pitch":
		var users = user_pitch_riffs.get(key, []).duplicate(true)
		# No builtins for pitch yet
		return users
	else:
		# Interval logic (with builtins)
		var candidates = user_riffs.get(key, []).duplicate(true)
		
		# [v0.6] Direction Filtering
		# mode: 0 (Ascending), 1 (Descending), 2 (Harmonic->Ascending?)
		if mode != -1 and not candidates.is_empty():
			var filtered = []
			# Map Harmonic (2) to Ascending (0) or Any? Let's say Harmonic can use Ascending.
			var target_direction = 1 if mode == 1 else 0
			
			for riff in candidates:
				# Default to Ascending (0) if direction missing
				var dir = riff.get("direction", 0)
				if dir == target_direction:
					filtered.append(riff)
			
			if not filtered.is_empty():
				return filtered
			# If filtered empty, fallback to ALL (User might not have added desc riffs yet)
			print("[RiffManager] No riffs found for direction %d, falling back to all." % target_direction)
		
		return candidates

func set_playback_preference(key: int, type: String, mode: String, riff_id: String = "") -> void:
	var pref_key = "%s_%d" % [type, key]
	playback_preferences[pref_key] = {
		"mode": mode, # "random" or "single"
		"id": riff_id
	}
	_save_riffs()

func get_playback_preference(key: int, type: String) -> Dictionary:
	var pref_key = "%s_%d" % [type, key]
	return playback_preferences.get(pref_key, {"mode": "random", "id": ""})


func _save_riffs() -> void:
	var riff_data = {
		"interval_riffs": user_riffs,
		"pitch_riffs": user_pitch_riffs,
		"preferences": playback_preferences
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(riff_data, "\t"))
		file.close()

func _load_riffs() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var data = json.data
			if data is Dictionary and data.has("interval_riffs"):
				# New Format
				# Convert keys to int as JSON keys are strings
				user_riffs = {}
				for k in data["interval_riffs"]:
					user_riffs[int(k)] = data["interval_riffs"][k]
					
				user_pitch_riffs = {}
				if data.has("pitch_riffs"):
					for k in data["pitch_riffs"]:
						user_pitch_riffs[int(k)] = data["pitch_riffs"][k]
				
				if data.has("preferences"):
					playback_preferences = data["preferences"]
			elif data is Dictionary:
				# Legacy Format (Direct dictionary of interval riffs)
				user_riffs = {}
				for k in data:
					user_riffs[int(k)] = data[k]
				user_pitch_riffs = {} # Init empty for migration
		file.close()

func _get_builtin_riffs(key: int) -> Array:
	var result = []
	if IntervalQuizData.INTERVALS.has(key):
		var info = IntervalQuizData.INTERVALS[key]
		if info.has("examples"):
			for ex in info.examples:
				var riff = {
					"title": ex.title,
					"source": "builtin",
					"id": "builtin_" + ex.title.to_snake_case(),
					"notes": []
				}
				
				# Convert motif (semitones) to Riff Notes format
				# For playback, we need valid 'pitch' relative to a root (say 60/C4)
				# But wait, Riff Playback logic might handle relative notes?
				# The current _play_riff_snippet expects {pitch, string, start_ms, duration_ms}.
				# Actually, the built-in motifs are just relative intervals [0, 4, 7].
				# The system stores them as "notes".
				# Let's synthesize a default rhythm (quarter notes).
				
				if ex.has("motif"):
					var start_ms = 0
					var duration = 500 # 0.5s per note
					for interval in ex.motif:
						# Store purely relative interval in pitch? Or synthesize a C major root?
						# Riffs usually store absolute MIDI pitch for user recording.
						# But for relative display, we might want to transpose?
						# For now, let's map to C4 (60) + interval.
						riff.notes.append({
							"pitch": 60 + interval,
							"string": - 1, # Auto
							"start_ms": start_ms,
							"duration_ms": 400
						})
						start_ms += duration
				
				result.append(riff)
	return result
