# base_quiz_handler.gd
extends RefCounted
class_name BaseQuizHandler

var manager: Node # Reference to QuizManager for shared utilities

func _init(p_manager: Node):
	manager = p_manager

# --- Virtual Methods ---

func start_quiz() -> void:
	pass

func check_answer(_input: Variant) -> void:
	pass

func on_tile_clicked(_clicked_note: int, _string_idx: int) -> void:
	pass

func stop_playback() -> void:
	pass

func replay() -> void:
	pass

func get_state() -> Dictionary:
	return {}

# --- Shared Utilities (Can be used by subclasses) ---

func _play_sfx(name: String) -> void:
	AudioEngine.play_sfx(name)

func _play_note(midi_note: int) -> void:
	AudioEngine.play_note(midi_note)
