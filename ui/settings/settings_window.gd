class_name SettingsWindow
extends BaseSidePanel

# ============================================================
# STATE
# ============================================================
# Registry for all active controls by key to reuse sync logic
var _controls: Dictionary = {}

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	super._ready() # Base calls _build_content

# ============================================================
# PUBLIC API
# ============================================================
func open() -> void:
	super.open()
	_sync_settings_from_game_manager()

# ============================================================
# VIRTUAL METHODS (Overridden)
# ============================================================
func _build_content() -> void:
	# 1. Capture References BEFORE reparenting
	# Reparenting ScrollContainer can break %UniqueName lookup if the scene tree updates
	var scroll = %ScrollContainer
	
	var master_vol = %MasterVol
	var chord_vol = %ChordVol
	var melody_vol = %MelodyVol
	var sfx_vol = %SFXVol
	
	var not_mode = %NotationMode
	
	var show_lbl = %ShowLabels
	var hl_root = %HighlightRoot
	var hl_chord = %HighlightChord
	var hl_scale = %HighlightScale
	var ui_scale = %UIScale
	var ui_scale_lbl = %UIScaleLbl
	
	var str_focus = %StringFocus
	var focus_lbl = %FocusRangeLbl
	var focus_min = %FocusRangeMinus
	var focus_plus = %FocusRangePlus
	var dead_lbl = %DeadzoneLbl
	var dead_min = %DeadzoneMinus
	var dead_plus = %DeadzonePlus

	# 2. Integrate Scene Layout into BaseSidePanel
	remove_child(scroll)
	_content_container.add_child(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 3. Setup Controls Map & Connections using captured references
	_setup_volume_controls(master_vol, chord_vol, melody_vol, sfx_vol)
	_setup_notation_controls(not_mode)
	_setup_display_controls(show_lbl, hl_root, hl_chord, hl_scale, ui_scale, ui_scale_lbl)
	_setup_camera_controls(str_focus, focus_lbl, focus_min, focus_plus, dead_lbl, dead_min, dead_plus)

# ============================================================
# SETUP & CONNECTIONS
# ============================================================
func _setup_volume_controls(master: HSlider, chord: HSlider, melody: HSlider, sfx: HSlider) -> void:
	_connect_volume_slider("Master", "Master", master)
	_connect_volume_slider("Chord", "Chord", chord)
	_connect_volume_slider("Melody", "Melody", melody)
	_connect_volume_slider("SFX", "SFX", sfx)

func _connect_volume_slider(key: String, bus_name: String, slider: HSlider) -> void:
	_controls[key] = slider # For sync
	
	if not slider.value_changed.is_connected(_on_volume_changed):
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))

func _on_volume_changed(val: float, bus_name: String) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(val))
		AudioServer.set_bus_mute(idx, val < 0.01)

func _setup_notation_controls(opt: OptionButton) -> void:
	_controls["notation_mode"] = opt
	
	if not opt.item_selected.is_connected(_on_notation_changed):
		opt.item_selected.connect(_on_notation_changed)

func _on_notation_changed(idx: int) -> void:
	GameManager.current_notation_mode = idx
	GameManager.save_settings()

func _setup_display_controls(show_lbl: CheckBox, hl_root: CheckBox, hl_chord: CheckBox, hl_scale: CheckBox, ui_scale: HSlider, ui_lbl: Label) -> void:
	_connect_checkbox("show_labels", show_lbl, func(v): GameManager.show_note_labels = v; GameManager.save_settings())
	_connect_checkbox("highlight_root", hl_root, func(v): GameManager.highlight_root = v; GameManager.save_settings())
	_connect_checkbox("highlight_chord", hl_chord, func(v): GameManager.highlight_chord = v; GameManager.save_settings())
	_connect_checkbox("highlight_scale", hl_scale, func(v): GameManager.highlight_scale = v; GameManager.save_settings())
	
	# UI Scale
	_controls["ui_scale"] = ui_scale
	_controls["ui_scale_lbl"] = ui_lbl
	
	if not ui_scale.value_changed.is_connected(_on_ui_scale_changed):
		ui_scale.value_changed.connect(_on_ui_scale_changed.bind(ui_lbl))

func _on_ui_scale_changed(v: float, lbl: Label) -> void:
	GameManager.ui_scale = v
	lbl.text = "%.2f" % v
	GameManager.save_settings()

func _connect_checkbox(key: String, cb: CheckBox, callback: Callable) -> void:
	_controls[key] = cb
	if not cb.toggled.is_connected(callback):
		cb.toggled.connect(callback)

func _setup_camera_controls(str_focus: OptionButton, f_lbl: Label, f_min: Button, f_plus: Button, d_lbl: Label, d_min: Button, d_plus: Button) -> void:
	# String Focus
	_controls["string_focus"] = str_focus
	if not str_focus.item_selected.is_connected(_on_string_focus_changed):
		str_focus.item_selected.connect(_on_string_focus_changed.bind(str_focus))
	
	# Focus Range
	_controls["focus_range_lbl"] = f_lbl
	if not f_min.pressed.is_connected(_update_focus_range):
		f_min.pressed.connect(_update_focus_range.bind(-1))
		f_plus.pressed.connect(_update_focus_range.bind(1))
	
	# Deadzone
	_controls["deadzone_lbl"] = d_lbl
	if not d_min.pressed.is_connected(_update_deadzone):
		d_min.pressed.connect(_update_deadzone.bind(-1))
		d_plus.pressed.connect(_update_deadzone.bind(1))

func _on_string_focus_changed(idx: int, opt: OptionButton) -> void:
	var range_val = opt.get_item_id(idx)
	GameManager.string_focus_range = range_val
	GameManager.save_settings()

# ============================================================
# LOGIC HELPERS
# ============================================================
func _update_focus_range(delta: int) -> void:
	GameManager.focus_range = clampi(GameManager.focus_range + delta, 1, 12)
	_update_value_label("focus_range_lbl", str(GameManager.focus_range))
	GameManager.save_settings()

func _update_deadzone(dir: int) -> void:
	GameManager.camera_deadzone = clampf(GameManager.camera_deadzone + (dir * 0.5), 0.0, 10.0)
	_update_value_label("deadzone_lbl", str(GameManager.camera_deadzone))
	GameManager.save_settings()

func _update_value_label(key: String, text: String) -> void:
	if _controls.has(key):
		_controls[key].text = text

# ============================================================
# SYNC LOGIC
# ============================================================
func _sync_settings_from_game_manager() -> void:
	# Notation
	if _controls.has("notation_mode"):
		_controls["notation_mode"].select(GameManager.current_notation_mode)
	
	# Display
	if _controls.has("show_labels"): _controls["show_labels"].set_pressed_no_signal(GameManager.show_note_labels)
	if _controls.has("highlight_root"): _controls["highlight_root"].set_pressed_no_signal(GameManager.highlight_root)
	if _controls.has("highlight_chord"): _controls["highlight_chord"].set_pressed_no_signal(GameManager.highlight_chord)
	if _controls.has("highlight_scale"): _controls["highlight_scale"].set_pressed_no_signal(GameManager.highlight_scale)
	
	# UI Scale
	if _controls.has("ui_scale"):
		_controls["ui_scale"].set_value_no_signal(GameManager.ui_scale)
	_update_value_label("ui_scale_lbl", "%.2f" % GameManager.ui_scale)
	
	# Camera
	if _controls.has("string_focus"):
		var opt = _controls["string_focus"]
		var current_range = GameManager.string_focus_range
		for i in range(opt.item_count):
			if opt.get_item_id(i) == current_range:
				opt.select(i)
				break
	
	_update_value_label("focus_range_lbl", str(GameManager.focus_range))
	_update_value_label("deadzone_lbl", str(GameManager.camera_deadzone))
	
	# Volume
	for key in ["Master", "Chord", "Melody", "SFX"]:
		if _controls.has(key):
			var idx = AudioServer.get_bus_index(key)
			if idx != -1:
				_controls[key].value = db_to_linear(AudioServer.get_bus_volume_db(idx))
