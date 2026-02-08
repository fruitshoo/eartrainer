# library_window.gd
# 전용 라이브러리 창 - 프리셋(진행) 및 곡(Song) 목록 관리
class_name LibraryWindow
extends Control

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
var name_input: LineEdit
var save_btn: Button
var close_button: Button

# ============================================================
# STATE
# ============================================================
var current_mode: LibraryTabMode = LibraryTabMode.PRESETS
var selected_item: String = ""

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_build_ui()
	visible = false
	_refresh_list()

func open() -> void:
	visible = true
	_refresh_list()
	# Optional zoom-in animation could be added here

func close() -> void:
	visible = false

# ============================================================
# UI BUILDER
# ============================================================
func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	theme = _main_theme
	
	# 1. Dimmer Background
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.4)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close())
	add_child(dimmer)
	
	# 2. Main Centered Panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 600)
	panel.theme_type_variation = "PanelContainerGlass"
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	for m in ["top", "left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 24)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# --- Title & Close ---
	var head = HBoxContainer.new()
	vbox.add_child(head)
	
	var title = Label.new()
	title.text = "Library"
	title.theme_type_variation = "HeaderMedium"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	
	close_button = Button.new()
	close_button.text = "✖"
	close_button.flat = true
	close_button.pressed.connect(close)
	head.add_child(close_button)
	
	# --- Mode Tabs (Progressions / Songs) ---
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	
	presets_tab_btn = _create_tab_button("Progressions", true)
	presets_tab_btn.toggled.connect(_on_mode_toggled.bind(LibraryTabMode.PRESETS))
	tabs.add_child(presets_tab_btn)
	
	songs_tab_btn = _create_tab_button("Songs", false)
	songs_tab_btn.toggled.connect(_on_mode_toggled.bind(LibraryTabMode.SONGS))
	tabs.add_child(songs_tab_btn)
	
	# --- Scrollable List ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	preset_list_container = VBoxContainer.new()
	preset_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(preset_list_container)
	
	vbox.add_child(HSeparator.new())
	
	# --- Save Input ---
	var save_row = HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	vbox.add_child(save_row)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter name to save..."
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(name_input)
	
	save_btn = Button.new()
	save_btn.text = "Save Current"
	save_btn.pressed.connect(_on_save_pressed)
	save_row.add_child(save_btn)

func _create_tab_button(text: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = active
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	return btn

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
