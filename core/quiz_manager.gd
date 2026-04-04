extends Node

const QUIZ_MANAGER_VISUALS = preload("res://core/quiz_manager_visuals.gd")
const QUIZ_MANAGER_PLAYBACK = preload("res://core/quiz_manager_playback.gd")
const QUIZ_MANAGER_SETTINGS = preload("res://core/quiz_manager_settings.gd")

# ============================================================
# SIGNALS
# ============================================================
# ============================================================
# SIGNALS
signal quiz_started(data: Dictionary) # { "type": "note"|"interval", ... }
signal quiz_answered(result: Dictionary) # { "correct": bool, "answer": ..., "target": ... }
signal quiz_step_completed(data: Dictionary) # [New] For multi-step quizzes
signal quiz_sequence_playing(step_idx: int) # [New] Emitted each time a chord in the sequence begins playing

# ============================================================
# ENUMS
# ============================================================
enum QuizType {NONE, NOTE_LOCATION, INTERVAL, PITCH_CLASS, CHORD_QUALITY, CHORD_LOCATION, CHORD_PROGRESSION}
enum IntervalMode {ASCENDING, DESCENDING, HARMONIC}
enum StringConstraint {ALL, SAME_STRING, CROSS_STRING}

# ============================================================
# STATE
# ============================================================
var current_quiz_type: QuizType = QuizType.NONE

# -- State Sync (Used by handlers/playback) --
var current_target_note: int = -1
var interval_root_note: int = -1
var interval_target_note: int = -1
var interval_semitones: int = 0
var current_interval_mode: int = 0 # 0=Asc, 1=Desc, 2=Harmonic
var pitch_target_class: int = -1
var pitch_target_note_actual: int = -1
var chord_target_type: String = ""
var _current_root_fret: int = -1

# -- Settings (Accessed by Handlers) --
var active_modes: Array = [IntervalMode.ASCENDING]
var active_intervals: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
var interval_diatonic_mode: bool = false # [New] Only in-key intervals
var interval_string_constraint: int = 0 # [New] 0=All, 1=Same, 2=Cross
var interval_harmonic_context: bool = false # [New] Play tonic chord before quiz
var interval_fixed_anchor: bool = false # [New] Keep same root for shapes
var interval_beginner_mode: bool = false # [New] Guided lessons for interval/fretboard mapping
var interval_beginner_lesson_index: int = 0
var active_pitch_classes: Array = [0, 2, 4, 5, 7, 9, 11]
var active_chord_types: Array = ["maj", "min"]
var chord_root_mode: String = "fixed"
var chord_fixed_root: int = 60

# [New] Chord Training Settings
var active_inversions: Array = [0] # 0=Root, 1=1st, 2=2nd
var active_directions: Array = [2] # [Fix #5] 0=Up, 1=Down, 2=Harmonic
var active_degrees: Array = [0, 1, 2, 3, 4, 5, 6] # [New] Diatonic degrees (I through vii°)
var active_progression_degrees: Array = [0, 3, 4, 5] # [New] I, IV, V, vi selected by default
var progression_level: int = 3 # [New] 1=2chords, 2=3chords, 3=4chords, 4=5chords, 5=6chords, etc
var use_power_chords: bool = false # [New] Power Chords only for progressions
var chord_quiz_use_voicing: bool = false # [New] false=Theory mode, true=Guitar Form mode

# -- Handler Strategy --
var _handlers: Dictionary = {}
var _active_handler: BaseQuizHandler = null
var _visual_helper: QuizManagerVisuals
var _playback_helper: QuizManagerPlayback
var _settings_helper: QuizManagerSettings

# ============================================================
# LIFECYCLE
# ============================================================
func _ready():
	_visual_helper = QUIZ_MANAGER_VISUALS.new(self)
	_playback_helper = QUIZ_MANAGER_PLAYBACK.new(self)
	_settings_helper = QUIZ_MANAGER_SETTINGS.new(self)
	EventBus.tile_clicked.connect(_on_tile_clicked)
	load_chord_settings()
	load_interval_settings()
	_init_handlers()

func _init_handlers():
	_handlers = {
		QuizType.PITCH_CLASS: PitchQuizHandler.new(self),
		QuizType.CHORD_QUALITY: ChordQuizHandler.new(self),
		QuizType.CHORD_LOCATION: ChordQuizHandler.new(self),
		QuizType.CHORD_PROGRESSION: ProgressionQuizHandler.new(self), # [New]
		QuizType.INTERVAL: IntervalQuizHandler.new(self),
		QuizType.NOTE_LOCATION: NoteQuizHandler.new(self)
	}

func _on_tile_clicked(note: int, string_idx: int, _modifiers: Dictionary):
	# Dispatch to active handler
	if current_quiz_type != QuizType.NONE and _active_handler:
		_active_handler.on_tile_clicked(note, string_idx)

# ============================================================
# CORE FUNCTIONS
# ============================================================

# State for restoring visuals
var _saved_visual_settings: Dictionary = {}

func _switch_to_handler(type: QuizType) -> BaseQuizHandler:
	_stop_playback()
	_clear_markers()
	
	current_quiz_type = type
	_active_handler = _handlers.get(type)
	return _active_handler

func start_pitch_quiz():
	var h = _switch_to_handler(QuizType.PITCH_CLASS)
	if h: h.start_quiz()
	
func start_progression_quiz(): # [New]
	var h = _switch_to_handler(QuizType.CHORD_PROGRESSION)
	if h: h.start_quiz()

func check_pitch_answer(clicked_note: int, string_idx: int):
	if _active_handler and current_quiz_type == QuizType.PITCH_CLASS:
		_active_handler.on_tile_clicked(clicked_note, string_idx)
		
func check_degree_progression_answer(degree_idx: int): # [New]
	if _active_handler and current_quiz_type == QuizType.CHORD_PROGRESSION:
		if _active_handler.has_method("on_degree_clicked"):
			_active_handler.on_degree_clicked(degree_idx)

func start_chord_quiz():
	var h = _switch_to_handler(QuizType.CHORD_QUALITY)
	if h: h.start_quiz()

func check_chord_answer(start_type: String):
	if _active_handler and current_quiz_type == QuizType.CHORD_QUALITY:
		_active_handler.check_answer(start_type)

func start_chord_location_quiz():
	var h = _switch_to_handler(QuizType.CHORD_LOCATION)
	if h: h.start_quiz()

func start_note_quiz():
	var h = _switch_to_handler(QuizType.NOTE_LOCATION)
	if h: h.start_quiz()

func check_note_answer(clicked_note: int):
	if _active_handler and current_quiz_type == QuizType.NOTE_LOCATION:
		_active_handler.check_answer(clicked_note)

func start_interval_quiz():
	var h = _switch_to_handler(QuizType.INTERVAL)
	if h: h.start_quiz()

func check_interval_answer_with_tile(note: int, string_idx: int):
	if _active_handler and current_quiz_type == QuizType.INTERVAL:
		_active_handler.on_tile_clicked(note, string_idx)

func get_interval_beginner_lesson() -> Dictionary:
	return IntervalQuizData.get_beginner_lesson(interval_beginner_lesson_index)

func get_interval_target_pos(target_note: int, root_str: int, root_fret: int, constraint: int) -> Dictionary:
	const MAX_FRET := 12

	if constraint == StringConstraint.ALL:
		for s in range(6):
			var f = target_note - AudioEngine.OPEN_STRING_MIDI[s]
			if f >= 0 and f <= MAX_FRET:
				return {"valid": true, "string": s, "fret": f}
		return {"valid": false}

	if constraint == StringConstraint.SAME_STRING:
		var same_fret = target_note - AudioEngine.OPEN_STRING_MIDI[root_str]
		if same_fret >= 0 and same_fret <= MAX_FRET:
			return {"valid": true, "string": root_str, "fret": same_fret}
		return {"valid": false}

	if constraint == StringConstraint.CROSS_STRING:
		for s in [root_str - 1, root_str + 1]:
			if s < 0 or s >= 6:
				continue
			var cross_fret = target_note - AudioEngine.OPEN_STRING_MIDI[s]
			if cross_fret >= 0 and cross_fret <= MAX_FRET and abs(cross_fret - root_fret) <= 6:
				return {"valid": true, "string": s, "fret": cross_fret}
		return {"valid": false}

	return {"valid": false}

func preview_beginner_interval(semitones: int) -> void:
	var lesson = get_interval_beginner_lesson()
	if lesson.is_empty():
		return

	_stop_playback()
	_clear_markers()

	var root_string = int(lesson.get("root_string", 1))
	var root_fret = int(lesson.get("root_fret", 5))
	var constraint = int(lesson.get("constraint", StringConstraint.SAME_STRING))
	var root_note = AudioEngine.OPEN_STRING_MIDI[root_string] + root_fret
	var target_note = root_note + semitones
	var target_pos = get_interval_target_pos(target_note, root_string, root_fret, constraint)
	var interval_info = IntervalQuizData.INTERVALS.get(semitones, {})
	var target_color = interval_info.get("color", Color(0.6, 0.8, 1.0))

	_highlight_tile(root_string, root_fret, Color.WHITE, 1.5)
	if target_pos.valid:
		_highlight_tile(target_pos.string, target_pos.fret, target_color, 0.9)

	_play_note_with_blink(root_note, 0.6, true)
	var my_id = _current_playback_id
	get_tree().create_timer(0.6).timeout.connect(func():
		if _current_playback_id != my_id:
			return
		_play_note_with_blink(target_note, 1.0, true)
	)

func _auto_hide_visuals():
	if _saved_visual_settings.is_empty():
		_saved_visual_settings = {
			"root": GameManager.highlight_root,
			"chord": GameManager.highlight_chord,
			"scale": GameManager.highlight_scale
		}
		# Disable all
		GameManager.highlight_root = false
		GameManager.highlight_chord = false
		
		# [Fix] Dim scale context during progression quizzes if hints are enabled for clarity
		if current_quiz_type == QuizType.CHORD_PROGRESSION and GameManager.show_target_visual:
			GameManager.highlight_scale = false
		# else keep scale visible for context if it was already on
		
		GameManager.settings_changed.emit() # Force update

# ============================================================
# UTILITIES
# ============================================================
func stop_quiz():
	_stop_playback()
	current_quiz_type = QuizType.NONE
	_active_handler = null
	_clear_markers()
	
	# [New] Restore Visual Settings
	if not _saved_visual_settings.is_empty():
		GameManager.highlight_root = _saved_visual_settings.get("root", true)
		GameManager.highlight_chord = _saved_visual_settings.get("chord", true)
		GameManager.highlight_scale = _saved_visual_settings.get("scale", true)
		GameManager.settings_changed.emit() # Force update
		_saved_visual_settings.clear()
		
	print("[QuizManager] Quiz Stopped.")

# start_note_quiz / check_note_answer removed, logic moved to NoteQuizHandler.gd


# ============================================================
# INTERVAL QUIZ LOGIC
# ============================================================

# start_interval_quiz removed, logic moved to IntervalQuizHandler.gd

# _play_chord_structure removed, moved to ChordQuizHandler.gd

# _pick_fallback_question removed, logic moved to IntervalQuizHandler.gd

func _find_valid_pos_for_note(midi_note: int, preferred_fret: int = -1) -> Dictionary:
	return _visual_helper.find_valid_pos_for_note(midi_note, preferred_fret)

# Find ALL valid positions for a note on the fretboard
func _find_all_positions_for_note(midi_note: int, min_string_idx: int = 0) -> Array:
	return _visual_helper.find_all_positions_for_note(midi_note, min_string_idx)

func _find_closest_root_for_pitch_class(pitch_class: int, anchor_fret: int = -1) -> Dictionary:
	return _visual_helper.find_closest_root_for_pitch_class(pitch_class, anchor_fret)

func highlight_root_positions(midi_note: int, clear_previous: bool = true):
	_visual_helper.highlight_root_positions(midi_note, clear_previous)

func _highlight_tile(string_idx: int, fret_idx: int, color: Color, energy: float = 1.0):
	_visual_helper.highlight_tile(string_idx, fret_idx, color, energy)

func _clear_markers():
	_visual_helper.clear_markers()

func highlight_found_tone(string_idx: int, fret_idx: int):
	_visual_helper.highlight_found_tone(string_idx, fret_idx)

func highlight_degree(degree_idx: int, clear_previous: bool = true):
	_visual_helper.highlight_degree(degree_idx, clear_previous)

func replay_current_quiz():
	if _active_handler:
		_active_handler.replay()
	else:
		# Fallback for old system or if no handler active
		_stop_playback()
		_play_quiz_sound(current_quiz_type)

func _play_note_with_blink(note: int, duration: float = 0.3, force_visual: bool = true):
	_visual_helper.play_note_with_blink(note, duration, force_visual)

func _play_quiz_sound(type: QuizType):
	_playback_helper.play_quiz_sound(type)

# check_interval_answer removed - was unused legacy code

# check_interval_answer_with_tile removed, moved to IntervalQuizHandler.gd

# _show_feedback_text_for_note removed - was unimplemented

# ============================================================
# REWARD SYSTEM
# ============================================================

func _play_reward_song(key: int, mode: int) -> float:
	return _playback_helper.play_reward_song(key, mode)

# Playback Control
var _current_playback_id: int = 0
var _is_processing_correct_answer: bool = false

func _stop_playback():
	_playback_helper.stop_playback()

# Public wrapper for previewing riffs (e.g. from Example Manager)
func play_riff_preview(riff_data: Dictionary) -> void:
	_playback_helper.play_riff_preview(riff_data)

func _play_riff_snippet(riff_data: Dictionary) -> float:
	return _playback_helper.play_riff_snippet(riff_data)

func _play_builtin_motif(relative_notes: Array) -> float:
	return _playback_helper.play_builtin_motif(relative_notes)
# ============================================================
# SETTINGS PERSISTENCE
# ============================================================
func save_chord_settings():
	_settings_helper.save_chord_settings()

func load_chord_settings():
	_settings_helper.load_chord_settings()

func save_interval_settings():
	_settings_helper.save_interval_settings()

func load_interval_settings():
	_settings_helper.load_interval_settings()
