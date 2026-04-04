class_name LibraryWindowBehavior
extends RefCounted


func on_mode_toggled(window, toggled: bool, mode: int) -> void:
	if toggled and window.current_mode != mode:
		window.current_mode = mode
		if mode == window.LibraryTabMode.PRESETS:
			window.songs_tab_btn.set_pressed_no_signal(false)
		else:
			window.presets_tab_btn.set_pressed_no_signal(false)
		window.selected_item = ""
		refresh_list(window)


func refresh_list(window) -> void:
	if not window.preset_list_container:
		return

	for child in window.preset_list_container.get_children():
		child.queue_free()

	var list: Array = []
	if window.current_mode == window.LibraryTabMode.PRESETS:
		list = ProgressionManager.get_preset_list()
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			list = song_manager.get_song_list()

	for i in list.size():
		var data = list[i]
		var item = window.preset_item_scene.instantiate()
		window.preset_list_container.add_child(item)

		var display_data = data.duplicate()
		if window.current_mode == window.LibraryTabMode.SONGS:
			display_data["name"] = data.get("title", "Untitled")

		item.setup(display_data, i)
		item.load_requested.connect(window._on_load_requested)
		item.delete_requested.connect(window._on_delete_requested)
		if item.has_signal("item_clicked"):
			item.item_clicked.connect(window._on_item_clicked)

		if window.current_mode == window.LibraryTabMode.PRESETS:
			if item.has_signal("set_default_requested"):
				item.set_default_requested.connect(window._on_set_default)
			if item.has_signal("reorder_requested"):
				item.reorder_requested.connect(window._on_reorder)
			if item.has_method("set_is_default"):
				item.set_is_default(display_data.name == GameManager.default_preset_name)
		else:
			if item.has_method("set_reorder_visible"):
				item.set_reorder_visible(false)

	if not window.selected_item.is_empty():
		update_selection(window)


func on_save_pressed(window) -> void:
	var target_name: String = window.name_input.text.strip_edges()
	if target_name.is_empty():
		target_name = window.selected_item
	if target_name.is_empty():
		return

	if window.current_mode == window.LibraryTabMode.PRESETS:
		ProgressionManager.save_preset(target_name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.save_song(target_name)

	window.name_input.text = ""
	refresh_list(window)


func on_load_requested(window, item_name: String) -> void:
	if window.current_mode == window.LibraryTabMode.PRESETS:
		ProgressionManager.load_preset(item_name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.load_song(item_name)

	window.load_requested.emit(item_name, window.current_mode)
	window.close()


func on_delete_requested(window, item_name: String) -> void:
	if window.current_mode == window.LibraryTabMode.PRESETS:
		ProgressionManager.delete_preset(item_name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.delete_song(item_name)

	if window.selected_item == item_name:
		window.selected_item = ""
	refresh_list(window)


func on_item_clicked(window, item_name: String) -> void:
	window.selected_item = "" if window.selected_item == item_name else item_name
	if window.selected_item != "":
		window.name_input.text = item_name
	update_selection(window)


func update_selection(window) -> void:
	for child in window.preset_list_container.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child.preset_name == window.selected_item)


func on_set_default(window, item_name: String, is_default: bool) -> void:
	GameManager.default_preset_name = item_name if is_default else ""
	GameManager.save_settings()
	refresh_list(window)


func on_reorder(window, from_idx: int, to_idx: int) -> void:
	if window.current_mode == window.LibraryTabMode.PRESETS:
		ProgressionManager.reorder_presets(from_idx, to_idx)
		refresh_list(window)
