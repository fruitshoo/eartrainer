class_name QuizManagerSettings
extends RefCounted

const SETTINGS_PATH := "user://chord_quiz_settings.cfg"
const SETTINGS_PATH_INTERVAL := "user://interval_quiz_settings.cfg"

var manager

func _init(p_manager) -> void:
	manager = p_manager

func save_chord_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("chord_quiz", "active_degrees", manager.active_degrees)
	config.set_value("chord_progression", "active_progression_degrees", manager.active_progression_degrees)
	config.set_value("chord_progression", "progression_level", manager.progression_level)
	config.set_value("chord_progression", "use_power_chords", manager.use_power_chords)
	config.set_value("chord_quiz", "active_directions", manager.active_directions)
	config.set_value("chord_quiz", "active_inversions", manager.active_inversions)
	config.set_value("chord_quiz", "use_voicing", manager.chord_quiz_use_voicing)
	config.save(SETTINGS_PATH)

func load_chord_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	manager.active_degrees = config.get_value("chord_quiz", "active_degrees", manager.active_degrees)
	manager.active_progression_degrees = config.get_value("chord_progression", "active_progression_degrees", manager.active_progression_degrees)
	manager.progression_level = config.get_value("chord_progression", "progression_level", manager.progression_level)
	manager.use_power_chords = config.get_value("chord_progression", "use_power_chords", manager.use_power_chords)
	manager.active_directions = config.get_value("chord_quiz", "active_directions", manager.active_directions)
	manager.active_inversions = config.get_value("chord_quiz", "active_inversions", manager.active_inversions)
	manager.chord_quiz_use_voicing = config.get_value("chord_quiz", "use_voicing", manager.chord_quiz_use_voicing)

func save_interval_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("interval_quiz", "active_intervals", manager.active_intervals)
	config.set_value("interval_quiz", "active_modes", manager.active_modes)
	config.set_value("interval_quiz", "diatonic_mode", manager.interval_diatonic_mode)
	config.set_value("interval_quiz", "string_constraint", manager.interval_string_constraint)
	config.set_value("interval_quiz", "harmonic_context", manager.interval_harmonic_context)
	config.set_value("interval_quiz", "fixed_anchor", manager.interval_fixed_anchor)
	config.set_value("interval_quiz", "beginner_mode", manager.interval_beginner_mode)
	config.set_value("interval_quiz", "beginner_lesson_index", manager.interval_beginner_lesson_index)
	config.save(SETTINGS_PATH_INTERVAL)

func load_interval_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH_INTERVAL)
	if err != OK:
		return

	manager.active_intervals = config.get_value("interval_quiz", "active_intervals", manager.active_intervals)
	manager.active_modes = config.get_value("interval_quiz", "active_modes", manager.active_modes)
	manager.interval_diatonic_mode = config.get_value("interval_quiz", "diatonic_mode", manager.interval_diatonic_mode)
	manager.interval_string_constraint = config.get_value("interval_quiz", "string_constraint", manager.interval_string_constraint)
	manager.interval_harmonic_context = config.get_value("interval_quiz", "harmonic_context", manager.interval_harmonic_context)
	manager.interval_fixed_anchor = config.get_value("interval_quiz", "fixed_anchor", manager.interval_fixed_anchor)
	manager.interval_beginner_mode = config.get_value("interval_quiz", "beginner_mode", manager.interval_beginner_mode)
	manager.interval_beginner_lesson_index = config.get_value("interval_quiz", "beginner_lesson_index", manager.interval_beginner_lesson_index)
