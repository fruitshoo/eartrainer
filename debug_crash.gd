extends SceneTree

func _init():
	print("--- Starting Debug ---")
	
	# Load Classes
	var mt_script = load("res://core/music_theory.gd")
	var cq_data_script = load("res://core/data/chord_quiz_data.gd")
	var mt = mt_script.new() # It's static mostly, but instance for safety
	var cq = cq_data_script.new()
	
	var modes = [
		mt_script.ScaleMode.MAJOR,
		mt_script.ScaleMode.MINOR,
		mt_script.ScaleMode.MAJOR_PENTATONIC
	]
	
	for mode in modes:
		print("Testing Mode: ", mode)
		var scale_intervals = mt_script.SCALE_INTERVALS[mode]
		print("Intervals: ", scale_intervals)
		
		# Test Degrees 0..6
		for deg in range(7):
			print("  Degree: ", deg)
			
			if deg >= scale_intervals.size():
				print("    ! Skipping (Degree > Size)")
				continue
				
			var degree_semitone = scale_intervals[deg]
			var root = 60 + degree_semitone
			
			# Simulate get_diatonic_type
			var type = mt_script.get_diatonic_type(root, 60, mode)
			print("    Type: ", type)
			
			# Simulate Handler Logic
			var quality = "Major"
			if type.begins_with("m") and not type.begins_with("maj"):
				quality = "Minor"
				if "b5" in type or "dim" in type: quality = "Diminished"
			elif type.begins_with("dim"):
				quality = "Diminished"
				
			print("    Quality: ", quality)
			var ivs = cq_data_script.CHORD_QUALITIES[quality]
			print("    Intervals: ", ivs)
			
			# Sanity check index access?
			# var val = ivs[3] # This would crash
			
	print("--- Done ---")
	quit()
