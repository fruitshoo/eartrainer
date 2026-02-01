extends PanelContainer

signal close_requested

enum TabMode {PRESETS, SONGS}
var current_tab: TabMode = TabMode.PRESETS

@onready var close_button: Button = %CloseButton
@onready var preset_list_container: VBoxContainer = %PresetListContainer
@onready var name_input: LineEdit = %NameInput
@onready var save_button: Button = %SaveButton

@onready var presets_tab_button: Button = %PresetsTab
@onready var songs_tab_button: Button = %SongsTab

var preset_item_scene: PackedScene = preload("res://ui/sequence/library_panel/preset_item.tscn")
var selected_item_name: String = ""

func _ready() -> void:
	close_button.pressed.connect(func(): close_requested.emit())
	save_button.pressed.connect(_on_save_pressed)
	
	if presets_tab_button:
		presets_tab_button.toggled.connect(_on_presets_tab_toggled)
	if songs_tab_button:
		songs_tab_button.toggled.connect(_on_songs_tab_toggled)
	
	# Initial Refresh
	_update_tab_visuals()
	refresh_list()

func _on_presets_tab_toggled(toggled: bool) -> void:
	if toggled and current_tab != TabMode.PRESETS:
		current_tab = TabMode.PRESETS
		_update_tab_visuals()
		selected_item_name = ""
		refresh_list()

func _on_songs_tab_toggled(toggled: bool) -> void:
	if toggled and current_tab != TabMode.SONGS:
		current_tab = TabMode.SONGS
		_update_tab_visuals()
		selected_item_name = ""
		refresh_list()

func _update_tab_visuals() -> void:
	if presets_tab_button:
		presets_tab_button.set_pressed_no_signal(current_tab == TabMode.PRESETS)
	if songs_tab_button:
		songs_tab_button.set_pressed_no_signal(current_tab == TabMode.SONGS)

func refresh_list() -> void:
	# Clear
	for child in preset_list_container.get_children():
		child.queue_free()
	
	var list = []
	if current_tab == TabMode.PRESETS:
		list = ProgressionManager.get_preset_list()
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			list = song_manager.get_song_list()
	
	# Populate
	for i in range(list.size()):
		var data = list[i]
		var item = preset_item_scene.instantiate()
		preset_list_container.add_child(item)
		
		# Name key difference: Presets use "name", Songs use "title"
		# Adapting data for setup if needed, or rely on duck typing if "name" is used.
		# `preset_item.gd` likely expects `data.name`.
		# SongManager saves "title". I should normalize this or fix `preset_item.gd`.
		# Let's normalize data here for display.
		var display_data = data.duplicate()
		if current_tab == TabMode.SONGS:
			display_data["name"] = data.get("title", "Untitled")
			
		item.setup(display_data, i) # Pass Index
		item.load_requested.connect(_on_load_requested)
		item.delete_requested.connect(_on_delete_requested)
		
		# Connect selection & default signals
		if item.has_signal("item_clicked"):
			item.item_clicked.connect(_on_item_clicked)
			
		if current_tab == TabMode.PRESETS:
			if item.has_signal("set_default_requested"):
				item.set_default_requested.connect(_on_preset_set_default)
			if item.has_signal("reorder_requested"):
				item.reorder_requested.connect(_on_reorder_requested)
				
			# Set Default State (Presets only)
			if item.has_method("set_is_default"):
				var is_def = (display_data.name == GameManager.default_preset_name)
				item.set_is_default(is_def)
		else:
			# Hide reorder/star for songs (optional, maybe implementing later)
			if item.has_method("set_reorder_visible"):
				item.set_reorder_visible(false) # Needs to be added to preset_item
			
	# Restore selection if exists
	if not selected_item_name.is_empty():
		_update_selection_visuals()

func _on_save_pressed() -> void:
	var input_name = name_input.text.strip_edges()
	var target_name = ""
	
	if not input_name.is_empty():
		target_name = input_name
	elif not selected_item_name.is_empty():
		target_name = selected_item_name
	else:
		return
		
	if current_tab == TabMode.PRESETS:
		ProgressionManager.save_preset(target_name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.save_song(target_name)
			
	name_input.text = "" # Clear input
	selected_item_name = ""
	refresh_list()

func _on_load_requested(name: String) -> void:
	if current_tab == TabMode.PRESETS:
		ProgressionManager.load_preset(name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.load_song(name)
	
	selected_item_name = ""
	_update_selection_visuals()
	EventBus.request_close_settings.emit()

func _on_delete_requested(name: String) -> void:
	if current_tab == TabMode.PRESETS:
		ProgressionManager.delete_preset(name)
	else:
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.delete_song(name)
			
	if selected_item_name == name:
		selected_item_name = ""
	refresh_list()

func _on_item_clicked(name: String) -> void:
	if selected_item_name == name:
		selected_item_name = ""
	else:
		selected_item_name = name
		name_input.text = name # [New] Auto-fill input for checking/renaming
	
	_update_selection_visuals()

func _update_selection_visuals() -> void:
	for child in preset_list_container.get_children():
		if child.has_method("set_selected"):
			var is_target = (child.preset_name == selected_item_name)
			child.set_selected(is_target)

func _on_preset_set_default(name: String, is_default: bool) -> void:
	if is_default:
		GameManager.default_preset_name = name
	else:
		if GameManager.default_preset_name == name:
			GameManager.default_preset_name = ""
			
	GameManager.save_settings()
	refresh_list()

func _on_reorder_requested(from_idx: int, to_idx: int) -> void:
	if current_tab == TabMode.PRESETS:
		ProgressionManager.reorder_presets(from_idx, to_idx)
		refresh_list()
	refresh_list()
