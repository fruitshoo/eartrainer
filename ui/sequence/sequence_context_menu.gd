extends PopupMenu
class_name SequenceContextMenu

# ============================================================
# SIGNALS
# ============================================================
signal chord_type_selected(type_code: String)
signal delete_requested()
signal replace_requested()

# ============================================================
# CONSTANTS
# ============================================================
const ID_DELETE = 999
const ID_REPLACE = 1000

# ============================================================
# STATE
# ============================================================
var target_slot_index: int = -1
var _special_menu: PopupMenu

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	name = "ChordContextMenu"
	_setup_ui()

# ============================================================
# PUBLIC API
# ============================================================
func show_at_mouse(slot_index: int) -> void:
	var data = ProgressionManager.get_slot(slot_index)
	if data == null or data.is_empty():
		return
		
	target_slot_index = slot_index
	_rebuild_menu(data)
	
	position = Vector2(get_viewport().get_mouse_position())
	popup()

# ============================================================
# PRIVATE METHODS
# ============================================================
func _setup_ui() -> void:
	# Apply Main Theme
	var main_theme = load("res://ui/resources/main_theme.tres")
	if main_theme:
		theme = main_theme
	
	id_pressed.connect(_on_id_pressed)
	
	# Setup Submenu
	_special_menu = PopupMenu.new()
	_special_menu.name = "SpecialVoicingsMenu"
	if main_theme:
		_special_menu.theme = main_theme
	
	add_child(_special_menu)
	_special_menu.id_pressed.connect(_on_special_menu_id_pressed)

func _rebuild_menu(data: Dictionary) -> void:
	clear()
	
	var root_note = data.get("root", 0)
	var string_idx = data.get("string", 0)
	
	# Replace Section
	add_item("코드 교체 (Replace)", ID_REPLACE)
	set_item_icon_modulate(item_count - 1, Color(0.4, 1.0, 0.4))
	add_separator()
	
	# 7th Chords
	add_separator("7화음 (7th)")
	_add_chord_item("M7", "M7", root_note, string_idx)
	_add_chord_item("7", "7", root_note, string_idx)
	_add_chord_item("m7", "m7", root_note, string_idx)
	_add_chord_item("m7b5", "m7b5", root_note, string_idx)
	
	# Tension
	add_separator("텐션 (Tension)")
	_add_chord_item("add9", "add9", root_note, string_idx)
	_add_chord_item("m9", "m9", root_note, string_idx)
	
	# Sus
	add_separator("서스 (Sus)")
	_add_chord_item("sus4", "sus4", root_note, string_idx)
	_add_chord_item("7sus4", "7sus4", root_note, string_idx)
	
	# Alteration
	add_separator("변형 (Alteration)")
	_add_chord_item("dim7", "dim7", root_note, string_idx)
	_add_chord_item("aug", "aug", root_note, string_idx)
	
	# Power
	add_separator("파워코드 (Power)")
	_add_chord_item("5", "5 (Power Chord)", root_note, string_idx)
	
	# Special Voicings Submenu
	_rebuild_special_menu(root_note, string_idx)
	
	# Delete Section
	add_separator()
	add_item("삭제 (Delete)", ID_DELETE)
	set_item_icon_modulate(item_count - 1, Color(1, 0.4, 0.4))

func _rebuild_special_menu(root_note: int, string_idx: int) -> void:
	var has_m2 = MusicTheory.has_voicing("M/2", string_idx)
	var has_m3 = MusicTheory.has_voicing("M/3", string_idx)
	
	if has_m2 or has_m3:
		_special_menu.clear()
		if has_m2: _add_chord_item("M/2", "Major / 2 (F/G)", root_note, string_idx, _special_menu)
		if has_m3: _add_chord_item("M/3", "Major / 3 (E/G#)", root_note, string_idx, _special_menu)
		
		add_separator()
		add_submenu_item("특수 보이싱 (Special) ▶", "SpecialVoicingsMenu")

func _add_chord_item(type_code: String, label: String, root: int, string_idx: int, target_menu: PopupMenu = null) -> void:
	if not MusicTheory.has_voicing(type_code, string_idx):
		return
		
	var use_flats = MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var note_name = MusicTheory.get_note_name(root, use_flats)
	var tab_str = MusicTheory.get_tab_string(root, type_code, string_idx)
	
	var text = "%s %s  (%s)" % [note_name, label, tab_str]
	
	var menu = target_menu if target_menu else self
	menu.add_item(text)
	menu.set_item_metadata(menu.item_count - 1, type_code)

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_id_pressed(id: int) -> void:
	if id == ID_DELETE:
		delete_requested.emit()
	elif id == ID_REPLACE:
		replace_requested.emit()
	else:
		var type_code = get_item_metadata(get_item_index(id))
		if type_code:
			chord_type_selected.emit(type_code)

func _on_special_menu_id_pressed(id: int) -> void:
	var type_code = _special_menu.get_item_metadata(id)
	if type_code:
		chord_type_selected.emit(type_code)
