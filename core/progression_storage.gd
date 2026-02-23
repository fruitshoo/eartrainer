class_name ProgressionStorage
extends RefCounted

const SAVE_PATH_SESSION = "user://last_session.json"
const SAVE_PATH_PRESETS = "user://presets.json"

func save_session(data: Dictionary) -> void:
	var success = _save_json(SAVE_PATH_SESSION, data)
	if not success:
		var real_path = ProjectSettings.globalize_path(SAVE_PATH_SESSION)
		print("Save FAILED! Path: %s" % real_path)

func load_session() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH_SESSION):
		print("No session file.")
		return {}
	
	var data = _load_json(SAVE_PATH_SESSION)
	if data == null:
		return {}
		
	return data

func get_preset_list() -> Array[Dictionary]:
	return _load_presets_safe()

func save_preset(name: String, current_data: Dictionary) -> void:
	if name.strip_edges().is_empty():
		return
		
	var presets = _load_presets_safe()
	
	var new_data = current_data.duplicate(true)
	new_data["name"] = name
	new_data["timestamp"] = Time.get_unix_time_from_system()
	
	# 중복 이름 확인: 덮어쓰기
	var found_idx = -1
	for i in range(presets.size()):
		if presets[i]["name"] == name:
			found_idx = i
			break
	
	if found_idx != -1:
		presets[found_idx] = new_data
	else:
		presets.append(new_data)
		
	_save_json(SAVE_PATH_PRESETS, presets)
	print("[ProgressionStorage] Preset saved: ", name)

func load_preset(name: String) -> Dictionary:
	var presets = _load_presets_safe()
	for p in presets:
		if p["name"] == name:
			return p
	return {}

func delete_preset(name: String) -> void:
	var presets = _load_presets_safe()
	var found_idx = -1
	for i in range(presets.size()):
		if presets[i]["name"] == name:
			found_idx = i
			break
			
	if found_idx != -1:
		presets.remove_at(found_idx)
		_save_json(SAVE_PATH_PRESETS, presets)
		print("[ProgressionStorage] Preset deleted: ", name)

func reorder_presets(from_idx: int, to_idx: int) -> void:
	var presets = _load_presets_safe()
	if from_idx < 0 or from_idx >= presets.size() or to_idx < 0 or to_idx >= presets.size():
		return
		
	var item = presets.pop_at(from_idx)
	presets.insert(to_idx, item)
	_save_json(SAVE_PATH_PRESETS, presets)

func _load_presets_safe() -> Array[Dictionary]:
	var raw_data = _load_json(SAVE_PATH_PRESETS)
	
	if raw_data == null:
		return []
		
	if raw_data is Dictionary:
		print("[ProgressionStorage] Migrating presets from Dict to Array...")
		var list: Array[Dictionary] = []
		for key in raw_data.keys():
			var item = raw_data[key]
			item["name"] = key
			list.append(item)
		list.sort_custom(func(a, b): return a.get("timestamp", 0) > b.get("timestamp", 0))
		_save_json(SAVE_PATH_PRESETS, list)
		return list
		
	if raw_data is Array:
		var typed_list: Array[Dictionary] = []
		for item in raw_data:
			if item is Dictionary:
				typed_list.append(item)
		return typed_list
		
	return []

func _save_json(path: String, data: Variant) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		return true
	var err = FileAccess.get_open_error()
	print("[ProgressionStorage] Error opening file %s: %d" % [path, err])
	return false

func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(text)
		if error == OK:
			return json.data
	return null
