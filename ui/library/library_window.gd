# library_window.gd
# 전용 라이브러리 창 - 프리셋(진행) 및 곡(Song) 목록 관리
class_name LibraryWindow
extends BaseSidePanel

# ============================================================
# ENUMS
# ============================================================
enum LibraryTabMode {PRESETS, SONGS}

# ============================================================
# SIGNALS
# ============================================================
signal load_requested(item_name: String, mode: LibraryTabMode)

# ============================================================
# RESOURCES
# ============================================================
var preset_item_scene: PackedScene = preload("res://ui/sequence/library_panel/preset_item.tscn")
var _main_theme: Theme = preload("res://ui/resources/main_theme.tres")

# ============================================================
# UI REFERENCES
# ============================================================
var presets_tab_btn: Button
var songs_tab_btn: Button
var preset_list_container: VBoxContainer
var save_btn: Button
var name_input: LineEdit

# ============================================================
# CONSTANTS & STATE
# ============================================================
var current_mode: LibraryTabMode = LibraryTabMode.PRESETS
var selected_item: String = ""

# ============================================================
# LIFECYCLE
# ============================================================
# _ready handled by BaseSidePanel -> _build_content

func open() -> void:
	# Force reset anchors/offsets to ensure correct right-side positioning
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_update_position(false) # Reset to closed state bounds first
	
	super.open()
	_refresh_list()

func close() -> void:
	super.close()

func set_open(do_open: bool) -> void:
	super.set_open(do_open)

# ============================================================
# VIRTUAL METHODS
# ============================================================
func _build_content() -> void:
	# 1. Capture References from Scene
	var main_container = %MainContainer
	presets_tab_btn = %PresetsTabBtn
	songs_tab_btn = %SongsTabBtn
	preset_list_container = %PresetListContainer
	name_input = %NameInput
	save_btn = %SaveBtn
	
	# 2. Integrate Scene Layout into BaseSidePanel
	# Move the pre-defined layout into the BaseSidePanel's content area
	if main_container:
		remove_child(main_container)
		_content_container.add_child(main_container)
		main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 3. Setup Connections
	presets_tab_btn.toggled.connect(_on_mode_toggled.bind(LibraryTabMode.PRESETS))
	songs_tab_btn.toggled.connect(_on_mode_toggled.bind(LibraryTabMode.SONGS))
	save_btn.pressed.connect(_on_save_pressed)
	
	# Theme setup (optional, scene might already have it)
	theme = _main_theme
	
	# Initial Refresh
	_refresh_list()


# ============================================================
# LOGIC
# ============================================================
func _on_mode_toggled(toggled: bool, mode: LibraryTabMode) -> void:
	if toggled and current_mode != mode:
		current_mode = mode
		if mode == LibraryTabMode.PRESETS: songs_tab_btn.set_pressed_no_signal(false)
		else: presets_tab_btn.set_pressed_no_signal(false)
		selected_item = ""
		_refresh_list()

func _refresh_list() -> void:
	if not preset_list_container: return
	for child in preset_list_container.get_children(): child.queue_free()
	
	var list = []
	if current_mode == LibraryTabMode.PRESETS:
		list = ProgressionManager.get_preset_list()
	else:
		var sm = GameManager.get_node_or_null("SongManager")
		if sm: list = sm.get_song_list()
			
	for i in list.size():
		var data = list[i]
		var item = preset_item_scene.instantiate()
		preset_list_container.add_child(item)
		var display_data = data.duplicate()
		if current_mode == LibraryTabMode.SONGS:
			display_data["name"] = data.get("title", "Untitled")
		item.setup(display_data, i)
		item.load_requested.connect(_on_load_requested)
		item.delete_requested.connect(_on_delete_requested)
		if item.has_signal("item_clicked"): item.item_clicked.connect(_on_item_clicked)
		
		# Metadata & Reordering only for Progressions
		if current_mode == LibraryTabMode.PRESETS:
			if item.has_signal("set_default_requested"): item.set_default_requested.connect(_on_set_default)
			if item.has_signal("reorder_requested"): item.reorder_requested.connect(_on_reorder)
			if item.has_method("set_is_default"):
				item.set_is_default(display_data.name == GameManager.default_preset_name)
		else:
			if item.has_method("set_reorder_visible"): item.set_reorder_visible(false)
			
	if not selected_item.is_empty(): _update_selection()

func _on_save_pressed() -> void:
	var target_name = name_input.text.strip_edges()
	if target_name.is_empty(): target_name = selected_item
	if target_name.is_empty(): return
	
	if current_mode == LibraryTabMode.PRESETS:
		ProgressionManager.save_preset(target_name)
	else:
		var sm = GameManager.get_node_or_null("SongManager")
		if sm: sm.save_song(target_name)
		
	name_input.text = ""
	_refresh_list()

func _on_load_requested(item_name: String) -> void:
	if current_mode == LibraryTabMode.PRESETS:
		ProgressionManager.load_preset(item_name)
	else:
		var sm = GameManager.get_node_or_null("SongManager")
		if sm: sm.load_song(item_name)
	
	load_requested.emit(item_name, current_mode)
	close()

func _on_delete_requested(item_name: String) -> void:
	if current_mode == LibraryTabMode.PRESETS:
		ProgressionManager.delete_preset(item_name)
	else:
		var sm = GameManager.get_node_or_null("SongManager")
		if sm: sm.delete_song(item_name)
	if selected_item == item_name: selected_item = ""
	_refresh_list()

func _on_item_clicked(item_name: String) -> void:
	selected_item = "" if selected_item == item_name else item_name
	if selected_item != "": name_input.text = item_name
	_update_selection()

func _update_selection() -> void:
	for child in preset_list_container.get_children():
		if child.has_method("set_selected"): child.set_selected(child.preset_name == selected_item)

func _on_set_default(item_name: String, is_default: bool) -> void:
	GameManager.default_preset_name = item_name if is_default else ""
	GameManager.save_settings()
	_refresh_list()

func _on_reorder(from_idx: int, to_idx: int) -> void:
	if current_mode == LibraryTabMode.PRESETS:
		ProgressionManager.reorder_presets(from_idx, to_idx)
		_refresh_list()
