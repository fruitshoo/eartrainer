class_name QuizManagerPlayback
extends RefCounted

var manager

func _init(p_manager) -> void:
	manager = p_manager

func play_quiz_sound(type) -> void:
	if manager._active_handler:
		manager._active_handler.replay()
		return

	if type == manager.QuizType.PITCH_CLASS:
		manager._play_note_with_blink(manager.pitch_target_note_actual)

func play_reward_song(key: int, mode: int) -> float:
	var quiz_type = "interval"
	if manager.current_quiz_type == manager.QuizType.PITCH_CLASS:
		quiz_type = "pitch"

	if not GameManager.has_node("RiffManager"):
		print("[QuizManager] RiffManager not found!")
		return 0.0

	var rm = GameManager.get_node("RiffManager")
	var candidates = rm.get_riffs(key, quiz_type, mode)
	if candidates.is_empty():
		print("No reward riff found for key %d (%s)" % [key, quiz_type])
		return 0.5

	var pref = rm.get_playback_preference(key, quiz_type)
	var winner = {}

	if pref.get("mode") == "single" and not pref.get("id", "").is_empty():
		var target_id = pref["id"]
		for cand in candidates:
			if cand.get("id") == target_id:
				winner = cand
				break
		if winner.is_empty():
			print("[QuizManager] Preferred riff not found, falling back to random.")
			winner = candidates.pick_random()
	else:
		winner = candidates.pick_random()

	print("[QuizManager] Playing Reward: %s (%s)" % [winner.get("title", "Untitled"), winner.get("source", "unknown")])
	return play_riff_snippet(winner)

func stop_playback() -> void:
	print("[QuizManager] Stopping Playback. ID: %d -> %d" % [manager._current_playback_id, manager._current_playback_id + 1])

	if manager._active_handler:
		manager._active_handler.stop_playback()

	manager._is_processing_correct_answer = false
	manager._current_playback_id += 1

	AudioEngine.stop_all_notes()
	EventBus.visual_note_off.emit(-1, -1)

func play_riff_preview(riff_data: Dictionary) -> void:
	stop_playback()
	play_riff_snippet(riff_data)

func play_riff_snippet(riff_data: Dictionary) -> float:
	var notes = riff_data.get("notes", [])
	var slots = riff_data.get("slots", [])
	var bpm = int(riff_data.get("bpm", 120))

	if notes.is_empty():
		return 0.0

	var my_id = manager._current_playback_id
	print("[QuizManager] Starting Riff Snippet (ID: %d). BPM: %d, Slots: %d" % [my_id, bpm, slots.size()])

	var first_ms = notes[0].start_ms
	var first_note_orig = notes[0].pitch
	var first_string_orig = notes[0].get("string", 0)
	var transpose_delta = manager.interval_root_note - first_note_orig

	var target_anchor_pitch = first_note_orig + transpose_delta
	while target_anchor_pitch < 40:
		target_anchor_pitch += 12
	while target_anchor_pitch > 84:
		target_anchor_pitch -= 12

	var anchor_fret = manager._current_root_fret if manager._current_root_fret != -1 else GameManager.player_fret
	var target_anchor_pos = manager._find_valid_pos_for_note(target_anchor_pitch, anchor_fret)
	var target_anchor_string = target_anchor_pos.string if target_anchor_pos.valid else 0
	var string_shift = target_anchor_string - first_string_orig
	var max_end_time = 0.0

	for n in notes:
		var delay = (n.start_ms - first_ms) / 1000.0
		var dur = n.duration_ms / 1000.0
		var note_end = delay + dur
		if note_end > max_end_time:
			max_end_time = note_end

		var pitch = n.pitch + transpose_delta
		while pitch < 40:
			pitch += 12
		while pitch > 84:
			pitch -= 12

		var orig_string = n.get("string", 0)
		var proposed_string = orig_string + string_shift
		var final_string = 0
		var valid_shape = false
		if proposed_string >= 0 and proposed_string <= 5:
			var open_notes = [40, 45, 50, 55, 59, 64]
			var fret = pitch - open_notes[proposed_string]
			if fret >= 0 and fret <= 19:
				final_string = proposed_string
				valid_shape = true
		if not valid_shape:
			var fallback_fret = manager._current_root_fret if manager._current_root_fret != -1 else GameManager.player_fret
			var fallback = manager._find_valid_pos_for_note(pitch, fallback_fret)
			final_string = fallback.string if fallback.valid else 0

		manager.get_tree().create_timer(delay).timeout.connect(func():
			if manager._current_playback_id != my_id:
				return

			AudioEngine.play_note(pitch)
			EventBus.visual_note_on.emit(pitch, final_string)

			manager.get_tree().create_timer(dur).timeout.connect(func():
				if manager._current_playback_id != my_id:
					return
				EventBus.visual_note_off.emit(pitch, final_string)
			)
		)

	if not slots.is_empty():
		var spb = 60.0 / bpm
		var current_beat = 0.0
		var beats_per_slot = 4.0

		for i in range(slots.size()):
			var slot = slots[i]
			if slot == null or slot.is_empty():
				current_beat += beats_per_slot
				continue

			var slot_start_sec = current_beat * spb
			var slot_dur_sec = beats_per_slot * spb
			var playback_delay = slot_start_sec - (first_ms / 1000.0)

			if playback_delay + slot_dur_sec > 0 and playback_delay < max_end_time:
				var root = slot.get("root", 0)
				var chord_type = slot.get("type", "")
				var transposed_root = root + transpose_delta
				var final_delay = max(0.0, playback_delay)
				var final_dur = slot_dur_sec
				if final_dur > 0:
					pass

				manager.get_tree().create_timer(final_delay).timeout.connect(func():
					if manager._current_playback_id != my_id:
						return

					var chord_intervals = ChordQuizData.get_chord_intervals(chord_type)
					for k in range(chord_intervals.size()):
						var n_pitch = transposed_root + chord_intervals[k]
						while n_pitch < 40:
							n_pitch += 12
						while n_pitch > 76:
							n_pitch -= 12
						AudioEngine.play_note(n_pitch)
				)

			current_beat += beats_per_slot

	return max_end_time

func play_builtin_motif(relative_notes: Array) -> float:
	var my_id = manager._current_playback_id
	var delay = 0.0
	var step = 0.4

	for rel in relative_notes:
		var pitch = manager.interval_root_note + rel

		manager.get_tree().create_timer(delay).timeout.connect(func():
			if manager._current_playback_id != my_id:
				return
			AudioEngine.play_note(pitch)
			EventBus.visual_note_on.emit(pitch, 0)
			manager.get_tree().create_timer(step * 0.8).timeout.connect(func():
				if manager._current_playback_id != my_id:
					return
				EventBus.visual_note_off.emit(pitch, 0)
			)
		)
		delay += step

	return delay + (step * 0.8)
