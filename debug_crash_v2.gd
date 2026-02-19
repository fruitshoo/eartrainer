extends SceneTree

func _init():
	print("--- Starting Deep Fuzz Debug ---")
	
	var mt_script = load("res://core/music_theory.gd")
	var cq_data_script = load("res://core/data/chord_quiz_data.gd")
	
	var modes = mt_script.ScaleMode.values()
	var keys = range(40, 80) # Test various root keys
	
	for mode in modes:
		var scale_intervals = mt_script.SCALE_INTERVALS.get(mode)
		if scale_intervals == null:
			print("! Missing Intervals for Mode: ", mode)
			continue
			
		for k in keys:
			for deg_idx in range(scale_intervals.size() + 2): # Go slightly out of bounds to test check
				# Emulate Handler Logic
				if deg_idx >= scale_intervals.size():
					# This should trigger the bounds check we added
					# print("OutOfBounds triggered for mode %d deg %d" % [mode, deg_idx])
					continue
					
				var degree_semitone = scale_intervals[deg_idx]
				var root_note = k + degree_semitone
				
				# Get Type
				var type_7th = mt_script.get_diatonic_type(root_note, k, mode)
				
				# Resolve Quality
				var quality = "Major"
				if type_7th.begins_with("m") and not type_7th.begins_with("maj"):
					quality = "Minor"
					if "b5" in type_7th or "dim" in type_7th:
						quality = "Diminished"
				elif type_7th.begins_with("dim"):
					quality = "Diminished"
				
				# Get Intervals
				var intervals = cq_data_script.CHORD_QUALITIES.get(quality)
				
				if intervals == null:
					print("!!! FATAL: No intervals for quality '%s' (Type: %s)" % [quality, type_7th])
					continue
					
				# Iterate (This is where the crash likely happens if loop goes too far)
				# The handler does: `for iv in intervals: ...` which is safe.
				# Wait, is there any manual index access?
				
				# Let's check MusicTheory.get_diatonic_type internals
				# It accesses SCALE_DATA[mode]["intervals"]
				
	print("--- Deep Fuzz Done (No Crash) ---")
	quit()
