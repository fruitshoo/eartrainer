class_name RiffManager
extends Node

const SAVE_PATH = "user://riffs.json"

# Dictionary of Interval Semitones -> Array of Riff Dictionaries
# { 4: [{title: "My Riff", notes: [...]}, ...] }
var user_riffs: Dictionary = {}

func _ready():
	_load_riffs()

func add_riff(interval: int, riff_data: Dictionary) -> void:
	if not user_riffs.has(interval):
		user_riffs[interval] = []
	
	# Add timestamp/ID if needed
	riff_data["id"] = Time.get_unix_time_from_system()
	user_riffs[interval].append(riff_data)
	_save_riffs()

func delete_riff(interval: int, riff_index: int) -> void:
	if user_riffs.has(interval) and riff_index >= 0 and riff_index < user_riffs[interval].size():
		user_riffs[interval].remove_at(riff_index)
		_save_riffs()

func get_riffs_for_interval(interval: int) -> Array:
	# Only return user riffs as requested
	var users = user_riffs.get(interval, []).duplicate(true)
	for u in users: u["source"] = "user"
	
	return users

func _save_riffs() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# JSON doesn't support integer keys nicely (converts to string), so we need to handle that on load
		file.store_string(JSON.stringify(user_riffs, "\t"))
		file.close()

func _load_riffs() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK:
			var data = json.data
			if data is Dictionary:
				user_riffs.clear()
				# Convert keys back to int
				for k in data.keys():
					var interval = int(k)
					user_riffs[interval] = data[k]
