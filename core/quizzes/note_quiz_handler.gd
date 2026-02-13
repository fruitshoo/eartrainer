# note_quiz_handler.gd
extends BaseQuizHandler
class_name NoteQuizHandler

var current_target_note: int = -1

func start_quiz() -> void:
	manager.current_quiz_type = manager.QuizType.NOTE_LOCATION
	
	# Select random string/fret (6 strings, 0-12 frets)
	var random_string = randi() % 6
	var random_fret = randi() % 13
	
	var root_notes = [40, 45, 50, 55, 59, 64]
	current_target_note = root_notes[random_string] + random_fret
	
	# Sync back to manager for playback
	manager.current_target_note = current_target_note
	
	_play_note(current_target_note)
	
	manager.quiz_started.emit({
		"type": "note",
		"target": current_target_note
	})
	print("[NoteQuizHandler] Note Quiz Target: ", current_target_note)

func check_answer(input: Variant) -> void:
	var clicked_note: int = int(input)
	if manager.current_quiz_type != manager.QuizType.NOTE_LOCATION: return
	
	var is_correct = (clicked_note == current_target_note)
	
	if is_correct:
		print("[NoteQuizHandler] Correct!")
		_play_sfx("correct")
		await manager.get_tree().create_timer(1.0).timeout
		start_quiz() 
	else:
		print("[NoteQuizHandler] Wrong!")
		_play_sfx("wrong") 
		_play_note(current_target_note)
		
	manager.quiz_answered.emit({"correct": is_correct})
