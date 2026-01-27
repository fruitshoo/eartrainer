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

# ============================================================
# LIFECYCLE
# ============================================================
func _ready():
	_setup_interval_grid()
	_connect_signals()
	_sync_state()

func _setup_interval_grid():
	# Clear existing if any (editor placeholder)
	for child in grid.get_children():
		child.queue_free()
		
	var data = IntervalQuizData.INTERVALS
	var sorted_semitones = data.keys()
	sorted_semitones.sort()
	
	for semitones in sorted_semitones:
		var info = data[semitones]
		
		# Row Container
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Checkbox
		var cb = CheckBox.new()
		cb.text = "%s (%s)" % [info.name, info.short]
		cb.tooltip_text = "Example: %s" % info.examples[0].get("title", "")
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Push edit button to right
		cb.toggled.connect(func(on): _on_interval_toggled(on, semitones))
		
		# Set initial state
		if semitones in QuizManager.active_intervals:
			cb.button_pressed = true
			
		checkboxes[semitones] = cb
		row.add_child(cb)
		
		# Edit Button
		var edit_btn = Button.new()
		edit_btn.text = "Edit" # Use icon eventually
		edit_btn.custom_minimum_size = Vector2(50, 0)
		edit_btn.pressed.connect(func(): _open_riff_editor(semitones))
		row.add_child(edit_btn)
		
		grid.add_child(row)

func _open_riff_editor(interval: int):
	var editor_scn = load("res://ui/quiz/RiffEditor.tscn")
	if editor_scn:
		var editor = editor_scn.instantiate()
		add_child(editor)
		editor.setup(interval)
		# Pause quiz interaction behind? Or just modal.
		# Ideally make it fill screen or be a popup. Using panel settings in tscn.

func _connect_signals():
	replay_btn.pressed.connect(func(): QuizManager.play_current_interval())
	next_btn.pressed.connect(func(): QuizManager.start_interval_quiz())
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
			if mode == QuizManager.IntervalMode.ASCENDING: asc_cb.set_pressed_no_signal(true)
			elif mode == QuizManager.IntervalMode.DESCENDING: desc_cb.set_pressed_no_signal(true)
			elif mode == QuizManager.IntervalMode.HARMONIC: harm_cb.set_pressed_no_signal(true)

func _on_interval_toggled(on: bool, semitones: int):
	# Update Manager
	if on:
		if not semitones in QuizManager.active_intervals:
			QuizManager.active_intervals.append(semitones)
	else:
		QuizManager.active_intervals.erase(semitones)
		
func _on_quiz_started(data: Dictionary):
	if data.type == "interval":
		feedback_label.text = "Listen..."
		feedback_label.modulate = Color.WHITE

func _on_quiz_answered(result: Dictionary):
	if result.correct:
		feedback_label.text = "Correct! Listen to the reward..."
		feedback_label.modulate = Color.CYAN
	else:
		feedback_label.text = "Try Again"
		feedback_label.modulate = Color(1, 0.3, 0.3)
