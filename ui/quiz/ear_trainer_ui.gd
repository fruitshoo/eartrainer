extends CanvasLayer

# ============================================================
# NODE REFERENCES (From Scene)
# ============================================================
@onready var asc_cb: CheckBox = %AscMode
@onready var desc_cb: CheckBox = %DescMode
@onready var harm_cb: CheckBox = %HarmMode

@onready var grid: GridContainer = %IntervalGrid
@onready var checkboxes: Dictionary = {}
@onready var feedback_label: Label = %FeedbackLabel
@onready var replay_btn: Button = %ReplayButton
@onready var next_btn: Button = %NextButton
@onready var close_btn: Button = %CloseButton

# Mode Switcher (Added via code)
var mode_container: VBoxContainer
var btn_mode_interval: Button
var btn_mode_pitch: Button
var btn_mode_chord: Button

var current_ui_mode: String = "interval" # "interval", "pitch", "chord"

# ============================================================
# LIFECYCLE
# ============================================================
func _ready():
	_setup_mode_switcher()
	_setup_grid()
	_connect_signals()
	_sync_state()

func _setup_mode_switcher():
	# Inject buttons above the grid (ScrollContainer). 
	# Grid is inside ScrollContainer, which is inside Main VBox.
	var scroll_container = grid.get_parent()
	var main_vbox = scroll_container.get_parent()
	
	if main_vbox:
		mode_container = VBoxContainer.new()
		mode_container.alignment = BoxContainer.ALIGNMENT_CENTER
		mode_container.add_theme_constant_override("separation", 10) # Reduced separation for vertical
		
		btn_mode_interval = Button.new()
		btn_mode_interval.text = "Interval Training"
		btn_mode_interval.toggle_mode = true
		btn_mode_interval.button_pressed = true
		btn_mode_interval.custom_minimum_size = Vector2(150, 40)
		btn_mode_interval.pressed.connect(func(): _set_ui_mode("interval"))
		
		btn_mode_pitch = Button.new()
		btn_mode_pitch.text = "Absolute Pitch"
		btn_mode_pitch.toggle_mode = true
		btn_mode_pitch.custom_minimum_size = Vector2(150, 40)
		btn_mode_pitch.pressed.connect(func(): _set_ui_mode("pitch"))
		
		btn_mode_chord = Button.new()
		btn_mode_chord.text = "Chord Quality"
		btn_mode_chord.toggle_mode = true
		btn_mode_chord.custom_minimum_size = Vector2(150, 40)
		btn_mode_chord.pressed.connect(func(): _set_ui_mode("chord"))
		
		mode_container.add_child(btn_mode_interval)
		mode_container.add_child(btn_mode_pitch)
		mode_container.add_child(btn_mode_chord)
		
		# Insert before ScrollContainer
		main_vbox.add_child(mode_container)
		main_vbox.move_child(mode_container, scroll_container.get_index())

func _set_ui_mode(mode: String):
	if current_ui_mode == mode: return
	
	current_ui_mode = mode
	
	# Update Toggles
	btn_mode_interval.set_pressed_no_signal(mode == "interval")
	btn_mode_pitch.set_pressed_no_signal(mode == "pitch")
	btn_mode_chord.set_pressed_no_signal(mode == "chord")
	
	# Refresh Grid
	_setup_grid()
	
	# Stop any current quiz
	QuizManager.stop_quiz()

func _setup_grid():
	# Clear existing
	for child in grid.get_children():
		if is_instance_valid(child):
			child.queue_free()
	checkboxes.clear()
		
	if current_ui_mode == "interval":
		_populate_interval_grid()
	elif current_ui_mode == "pitch":
		_populate_pitch_grid()
	elif current_ui_mode == "chord":
		_populate_chord_grid()

const ROW_SCENE = preload("res://ui/quiz/EarTrainerItemRow.tscn")

func _populate_chord_grid():
	var data = ChordQuizData.CHORDS
	var keys = ["maj", "min", "maj7", "min7", "dom7", "m7b5", "dim7"]
	
	for key in keys:
		if not data.has(key): continue
		var info = data[key]
		
		var row = ROW_SCENE.instantiate()
		grid.add_child(row) # Add first to ensure @on_ready runs
		
		var is_checked = key in QuizManager.active_chord_types
		row.setup(info.name, is_checked, false) # Hide edit for chords for now
		
		row.toggled.connect(func(on): _on_chord_toggled(on, key))
		
		checkboxes[key] = row.checkbox

func _populate_pitch_grid():
	var data = PitchQuizData.PITCH_CLASSES
	var sorted_keys = data.keys()
	sorted_keys.sort()
	
	for pc in sorted_keys:
		var info = data[pc]
		
		var row = ROW_SCENE.instantiate()
		grid.add_child(row)
		
		var is_checked = pc in QuizManager.active_pitch_classes
		row.setup(info.name, is_checked, true)
		
		row.toggled.connect(func(on): _on_pitch_toggled(on, pc))
		row.edit_requested.connect(func(): _open_riff_editor(pc, "pitch"))
		
		checkboxes[pc] = row.checkbox

func _populate_interval_grid():
	var data = IntervalQuizData.INTERVALS
	var sorted_semitones = data.keys()
	sorted_semitones.sort()
	
	for semitones in sorted_semitones:
		var info = data[semitones]
		
		var row = ROW_SCENE.instantiate()
		grid.add_child(row)
		
		var is_checked = semitones in QuizManager.active_intervals
		var text = "%s (%s)" % [info.name, info.short]
		
		row.setup(text, is_checked, true)
		# Set tooltip manually since setup doesnt handle it (optional polish)
		row.checkbox.tooltip_text = "Example: %s" % info.examples[0].get("title", "")
		
		row.toggled.connect(func(on): _on_interval_toggled(on, semitones))
		row.edit_requested.connect(func(): _open_riff_editor(semitones, "interval"))
		
		checkboxes[semitones] = row.checkbox

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Check for Open RiffEditor (Modal)
		for child in get_children():
			if child is RiffEditor:
				child.queue_free() # Close Editor
				get_viewport().set_input_as_handled()
				return
				
		# Check if we have focus on something else? 
		# If RiffEditor was not open, Close EarTrainer
		QuizManager.stop_quiz() # Ensure cleanup
		queue_free()
		get_viewport().set_input_as_handled()

func _open_riff_editor(key: int, type: String):
	var editor_scn = load("res://ui/quiz/RiffEditor.tscn")
	if editor_scn:
		var editor = editor_scn.instantiate()
		add_child(editor)
		editor.setup(key, type) # Needs explicit setup signature update in RiffEditor too
		
func _connect_signals():
	replay_btn.pressed.connect(func(): QuizManager.play_current_interval())
	next_btn.pressed.connect(func():
		if current_ui_mode == "interval":
			QuizManager.start_interval_quiz()
		elif current_ui_mode == "pitch":
			QuizManager.start_pitch_quiz()
		elif current_ui_mode == "chord":
			QuizManager.start_chord_quiz()
	)
	close_btn.pressed.connect(queue_free)
	
	asc_cb.toggled.connect(func(on): _on_mode_toggled(on, QuizManager.IntervalMode.ASCENDING))
	desc_cb.toggled.connect(func(on): _on_mode_toggled(on, QuizManager.IntervalMode.DESCENDING))
	harm_cb.toggled.connect(func(on): _on_mode_toggled(on, QuizManager.IntervalMode.HARMONIC))
	
	QuizManager.quiz_started.connect(_on_quiz_started)
	QuizManager.quiz_answered.connect(_on_quiz_answered)
	
	tree_exited.connect(func(): QuizManager.stop_quiz())

func _sync_state():
	# Sync Modes
	var modes = QuizManager.active_modes
	asc_cb.button_pressed = (QuizManager.IntervalMode.ASCENDING in modes)
	desc_cb.button_pressed = (QuizManager.IntervalMode.DESCENDING in modes)
	harm_cb.button_pressed = (QuizManager.IntervalMode.HARMONIC in modes)

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_mode_toggled(on: bool, mode: int):
	print("[EarTrainerUI] Toggled mode: ", mode, " On: ", on)
	if on:
		if not mode in QuizManager.active_modes:
			QuizManager.active_modes.append(mode)
	else:
		QuizManager.active_modes.erase(mode)
		# Prevent empty
		if QuizManager.active_modes.is_empty():
			print("[EarTrainerUI] Mode list empty! Reverting.")
			QuizManager.active_modes.append(mode)
			# Revert UI
			if mode == QuizManager.IntervalMode.DESCENDING: desc_cb.set_pressed_no_signal(true)
			elif mode == QuizManager.IntervalMode.HARMONIC: harm_cb.set_pressed_no_signal(true)
			elif mode == QuizManager.IntervalMode.ASCENDING: asc_cb.set_pressed_no_signal(true)

func _on_pitch_toggled(on: bool, pc: int):
	if on:
		if not pc in QuizManager.active_pitch_classes:
			QuizManager.active_pitch_classes.append(pc)
	else:
		QuizManager.active_pitch_classes.erase(pc)
		if QuizManager.active_pitch_classes.is_empty():
			QuizManager.active_pitch_classes.append(pc)
			if checkboxes.has(pc): checkboxes[pc].set_pressed_no_signal(true)

func _on_chord_toggled(on: bool, type: String):
	if on:
		if not type in QuizManager.active_chord_types:
			QuizManager.active_chord_types.append(type)
	else:
		QuizManager.active_chord_types.erase(type)
		if QuizManager.active_chord_types.is_empty():
			QuizManager.active_chord_types.append(type)
			if checkboxes.has(type): checkboxes[type].set_pressed_no_signal(true)


func _on_interval_toggled(on: bool, semitones: int):
	# Update Manager
	if on:
		if not semitones in QuizManager.active_intervals:
			QuizManager.active_intervals.append(semitones)
	else:
		QuizManager.active_intervals.erase(semitones)
		
func _on_quiz_started(data: Dictionary):
	if data.type == "interval":
		feedback_label.text = "Listen (Interval)..."
		feedback_label.modulate = Color.WHITE
	elif data.type == "pitch":
		feedback_label.text = "Listen (Absolute Pitch)..."
		feedback_label.modulate = Color.WHITE

func _on_quiz_answered(result: Dictionary):
	if result.correct:
		feedback_label.text = "Correct! Listen to the reward..."
		feedback_label.modulate = Color.CYAN
	else:
		feedback_label.text = "Try Again"
		feedback_label.modulate = Color(1, 0.3, 0.3)
