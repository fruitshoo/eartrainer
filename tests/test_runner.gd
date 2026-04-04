extends Node

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const UI_SCENE_PATH := "res://ui/main_ui.tscn"
const FRETBOARD_SCENE_PATH := "res://scenes/fretboard/fretboard_manager.tscn"

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("[TestRunner] Starting project validation...")

	_run_music_theory_tests()
	_run_quiz_api_smoke_tests()
	await _run_scene_smoke_tests()

	var total := _passed + _failed
	print("[TestRunner] Finished. Passed: %d Failed: %d Total: %d" % [_passed, _failed, total])

	if _failed == 0:
		print("[TestRunner] ALL TESTS PASSED")
	else:
		push_error("[TestRunner] TESTS FAILED")

	get_tree().quit(0 if _failed == 0 else 1)

func _run_music_theory_tests() -> void:
	print("[TestRunner] Suite: MusicTheory")

	_assert_equal(
		MusicTheory.get_diatonic_type(60, 0, MusicTheory.ScaleMode.MAJOR),
		"M7",
		"C major tonic resolves to M7"
	)
	_assert_equal(
		MusicTheory.get_diatonic_type(62, 0, MusicTheory.ScaleMode.MAJOR),
		"m7",
		"C major supertonic resolves to m7"
	)
	_assert_equal(
		MusicTheory.get_diatonic_type(67, 0, MusicTheory.ScaleMode.MAJOR),
		"7",
		"C major dominant resolves to 7"
	)
	_assert_true(
		MusicTheory.is_in_scale(64, 0, MusicTheory.ScaleMode.MAJOR),
		"E is in C major"
	)
	_assert_true(
		not MusicTheory.is_in_scale(61, 0, MusicTheory.ScaleMode.MAJOR),
		"Db is not in C major"
	)

	var degree_data := MusicTheory.get_chord_from_degree(MusicTheory.ScaleMode.MAJOR, 1)
	_assert_equal(degree_data.size(), 3, "Chord degree lookup returns interval, type, roman label")
	_assert_equal(degree_data[0], 2, "ii degree interval is 2 semitones in major")
	_assert_equal(degree_data[1], "m7", "ii degree quality is m7 in major")
	_assert_equal(degree_data[2], "ii", "ii degree roman label is lowercase ii")
	_assert_true(IntervalQuizData.BEGINNER_LESSONS.size() >= 1, "Beginner interval lessons are defined")

	var anchor := MusicTheory.get_preferred_quiz_anchor(9)
	_assert_equal(anchor.get("string"), 0, "A anchor uses 6th string")
	_assert_equal(anchor.get("fret"), 5, "A anchor uses 5th fret")

func _run_quiz_api_smoke_tests() -> void:
	print("[TestRunner] Suite: Autoload API")

		_assert_true(is_instance_valid(AudioEngine), "AudioEngine autoload is available")
		_assert_true(is_instance_valid(GameManager), "GameManager autoload is available")
		_assert_true(is_instance_valid(QuizManager), "QuizManager autoload is available")
		_assert_true(is_instance_valid(ProgressionManager), "ProgressionManager autoload is available")

		_assert_true(QuizManager.has_method("start_interval_quiz"), "QuizManager interval API exists")
		_assert_true(QuizManager.has_method("start_chord_quiz"), "QuizManager chord API exists")
		_assert_true(QuizManager.has_method("start_progression_quiz"), "QuizManager progression API exists")
		_assert_true(QuizManager.has_method("preview_beginner_interval"), "QuizManager beginner interval preview API exists")
		_assert_true(ProgressionManager.has_method("replace_all_melody_events"), "ProgressionManager melody replace API exists")
		_assert_true(ProgressionManager.has_method("set_section_label"), "ProgressionManager section label API exists")
		_assert_true(ProgressionManager.has_method("copy_bar"), "ProgressionManager bar copy API exists")
		_assert_true(ProgressionManager.has_method("paste_bar"), "ProgressionManager bar paste API exists")
		_assert_true(AudioEngine.has_method("play_note"), "AudioEngine note playback API exists")

		var melody_manager = GameManager.get_node_or_null("MelodyManager")
		_assert_true(melody_manager != null, "MelodyManager is registered on GameManager")
		if melody_manager:
			_assert_true(melody_manager.has_method("import_recorded_notes"), "MelodyManager legacy import API exists")
			_assert_true(melody_manager.has_method("sync_from_progression"), "MelodyManager sync API exists")

		QuizManager.start_pitch_quiz()
	_assert_equal(QuizManager.current_quiz_type, QuizManager.QuizType.PITCH_CLASS, "Pitch quiz starts successfully")
	_assert_true(QuizManager._active_handler != null, "Active handler is assigned when a quiz starts")
	QuizManager.stop_quiz()
	_assert_equal(QuizManager.current_quiz_type, QuizManager.QuizType.NONE, "stop_quiz resets current quiz type")
	_assert_true(QuizManager._active_handler == null, "stop_quiz clears the active handler")

func _run_scene_smoke_tests() -> void:
	print("[TestRunner] Suite: Scene Smoke")

	await _assert_scene_loads_and_instantiates(MAIN_SCENE_PATH)
	await _assert_scene_loads_and_instantiates(UI_SCENE_PATH)
	await _assert_scene_loads_and_instantiates(FRETBOARD_SCENE_PATH)

func _assert_scene_loads_and_instantiates(path: String) -> void:
	var packed_scene := load(path) as PackedScene
	_assert_true(packed_scene != null, "PackedScene loads: %s" % path)
	if packed_scene == null:
		return

	var instance := packed_scene.instantiate()
	_assert_true(instance != null, "PackedScene instantiates: %s" % path)
	if instance == null:
		return

	add_child(instance)
	await get_tree().process_frame
	instance.queue_free()
	await get_tree().process_frame

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		push_error("[FAIL] %s" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])
