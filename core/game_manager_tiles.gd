class_name GameManagerTiles
extends RefCounted

var manager

func _init(p_manager) -> void:
	manager = p_manager

func find_tile(string_idx: int, fret_idx: int) -> Node:
	var key = get_tile_key(string_idx, fret_idx)
	var tile = manager._tile_lookup.get(key)
	if tile and is_instance_valid(tile):
		return tile

	for fallback_tile in manager.get_tree().get_nodes_in_group("fret_tiles"):
		if fallback_tile.string_index == string_idx and fallback_tile.fret_index == fret_idx:
			manager._tile_lookup[key] = fallback_tile
			return fallback_tile
	return null

func register_fret_tile(tile: Node) -> void:
	if tile == null:
		return
	manager._tile_lookup[get_tile_key(tile.string_index, tile.fret_index)] = tile

func unregister_fret_tile(tile: Node) -> void:
	if tile == null:
		return
	var key = get_tile_key(tile.string_index, tile.fret_index)
	var cached = manager._tile_lookup.get(key)
	if cached == tile:
		manager._tile_lookup.erase(key)

func get_tile_key(string_idx: int, fret_idx: int) -> String:
	return "%d:%d" % [string_idx, fret_idx]

func on_melody_visual_on(midi_note: int, string_idx: int) -> void:
	var fret = MusicTheory.get_fret_position(midi_note, string_idx)
	var tile = find_tile(string_idx, fret)
	if tile and is_instance_valid(tile):
		if tile.has_method("apply_melody_highlight"):
			tile.apply_melody_highlight()

func on_melody_visual_off(midi_note: int, string_idx: int) -> void:
	if midi_note == -1:
		for tile in manager.get_tree().get_nodes_in_group("fret_tiles"):
			if tile.has_method("clear_melody_highlight"):
				tile.clear_melody_highlight()
		return

	var fret = MusicTheory.get_fret_position(midi_note, string_idx)
	var tile = find_tile(string_idx, fret)
	if tile and is_instance_valid(tile):
		if tile.has_method("clear_melody_highlight"):
			tile.clear_melody_highlight()
