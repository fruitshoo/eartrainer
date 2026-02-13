class_name KeySelectorPopup
extends PopupPanel

@onready var root_grid: GridContainer = %RootGrid
@onready var scale_option_button: OptionButton = %ScaleOptionButton

const ROOTS_MAJOR = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
const ROOTS_MINOR = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"]

func _ready() -> void:
	_build_grid()
	_setup_scale_options()
	
	# Update initially
	_update_visuals()

func _build_grid() -> void:
	for i in range(12):
		var btn = Button.new()
		# Text will be set in _update_visuals
		btn.custom_minimum_size = Vector2(30, 30)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_root_selected.bind(i))
		root_grid.add_child(btn)

func _setup_scale_options() -> void:
	scale_option_button.clear()
	
	# Explicit order for better UX
	var ordered_modes = [
		MusicTheory.ScaleMode.MAJOR,
		MusicTheory.ScaleMode.MINOR,
		MusicTheory.ScaleMode.DORIAN,
		MusicTheory.ScaleMode.PHRYGIAN,
		MusicTheory.ScaleMode.LYDIAN,
		MusicTheory.ScaleMode.MIXOLYDIAN,
		MusicTheory.ScaleMode.LOCRIAN,
		MusicTheory.ScaleMode.MAJOR_PENTATONIC,
		MusicTheory.ScaleMode.MINOR_PENTATONIC
	]
	
	for scale_mode in ordered_modes:
		var data = MusicTheory.SCALE_DATA.get(scale_mode)
		if data:
			scale_option_button.add_item(data["name"], scale_mode)
			
	scale_option_button.item_selected.connect(_on_scale_selected)

func _on_root_selected(root_idx: int) -> void:
	GameManager.current_key = root_idx
	_update_visuals()

func _on_scale_selected(index: int) -> void:
	var mode_id = scale_option_button.get_item_id(index)
	GameManager.current_mode = mode_id as MusicTheory.ScaleMode
	_update_visuals()

func _update_visuals() -> void:
	# Update Root Buttons Highlight & Text
	var current_key = GameManager.current_key
	
	# Determine if we should prioritize Flats or Sharps for Root Labels
	# Logic: Major-like = Flats, Minor-like = Sharps
	# Pentatonic Major -> Major-like, Pentatonic Minor -> Minor-like
	# Modes:
	# Dorian (Minor-like) -> Sharps
	# Phrygian (Minor-like) -> Sharps
	# Lydian (Major-like) -> Flats
	# Mixolydian (Major-like) -> Flats
	# Locrian (Minor-like) -> Sharps
	
	var is_major_like = true
	var mode_intervals = MusicTheory.SCALE_DATA[GameManager.current_mode]["intervals"]
	# Simple check: Major 3rd (4 semitones) vs Minor 3rd (3 semitones)
	if 3 in mode_intervals:
		is_major_like = false # It has a Minor 3rd
		
	var labels = ROOTS_MAJOR if is_major_like else ROOTS_MINOR
	
	for i in range(root_grid.get_child_count()):
		var btn = root_grid.get_child(i) as Button
		# Update Label Smartly
		if i < labels.size():
			btn.text = labels[i]
			
		if i == current_key:
			btn.modulate = Color(1.0, 0.8, 0.2) # Gold Highlight
		else:
			btn.modulate = Color.WHITE
			
	# Update OptionButton Selection (Sync if changed externally)
	var current_mode_id = GameManager.current_mode
	var idx = scale_option_button.get_item_index(current_mode_id)
	if idx != -1 and scale_option_button.selected != idx:
		scale_option_button.select(idx)

func popup_centered_under_control(control: Control) -> void:
	# Calculate position
	var rect = control.get_global_rect()
	var target_pos = rect.position
	target_pos.y += rect.size.y + 5 # Below
	target_pos.x += rect.size.x / 2.0 - size.x / 2.0 # Centered horizontally
	
	self.position = Vector2i(target_pos)
	self.popup()
	
	# Animate content (MarginContainer is the first child)
	var content = get_child(0) if get_child_count() > 0 else null
	if content:
		content.modulate.a = 0.0
		content.scale = Vector2(0.95, 0.95)
		content.pivot_offset = content.size / 2.0
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(true)
		tween.tween_property(content, "modulate:a", 1.0, 0.15)
		tween.tween_property(content, "scale", Vector2.ONE, 0.2)
