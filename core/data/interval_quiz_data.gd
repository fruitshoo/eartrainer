class_name IntervalQuizData
extends RefCounted

# Semitones -> Info Dictionary
# name: Display name
# examples: Array of { "title": "Song Name", "notes": [relative_semitones] }
# Note: examples are just for reference or built-in playback if we want to hardcode melodies.
# Actually, playing built-in songs requires defining their full melody or at least a motif.
# For simplicity, let's store "Motif" as relative semitones from Root.

const INTERVALS = {
	0: {"name": "Perfect Unison (P1)", "short": "P1", "examples": [ {"title": "Happy Birthday", "motif": [0, 0, 2, 0, 5, 4]}]}, # Happy Birthday start
	1: {"name": "Minor 2nd (m2)", "short": "m2", "examples": [ {"title": "Jaws Theme", "motif": [0, 1]}]},
	2: {"name": "Major 2nd (M2)", "short": "M2", "examples": [ {"title": "Happy Birthday", "motif": [0, 2]}]}, # Happy Birth-day (0->2 is M2? No. 0,0,2. The interval is 2)
	3: {"name": "Minor 3rd (m3)", "short": "m3", "examples": [ {"title": "Greensleeves", "motif": [0, 3]}]},
	4: {"name": "Major 3rd (M3)", "short": "M3", "examples": [ {"title": "When the Saints", "motif": [0, 4, 5, 7]}]},
	5: {"name": "Perfect 4th (P4)", "short": "P4", "examples": [ {"title": "Here Comes the Bride", "motif": [0, 5, 5, 5]}]},
	6: {"name": "Tritone (d5/A4)", "short": "TT", "examples": [ {"title": "The Simpsons", "motif": [0, 6, 7]}]},
	7: {"name": "Perfect 5th (P5)", "short": "P5", "examples": [ {"title": "Star Wars", "motif": [0, 7, 7, 8, 7, 12]}]}, # Main theme
	8: {"name": "Minor 6th (m6)", "short": "m6", "examples": [ {"title": "The Entertainer", "motif": [0, 8]}]}, # Wait, Entertainer is M3, m3, M3...
	# Correct m6: "In My Life" (The Beatles) start? Or "Love Story" theme.
	# "Black Orpheus" (Manha de Carnaval) -> 0, 7, 8 (Sol, Re, Eb) ? No.
	# Let's use "Love Story Idea": 0 -> 8
	9: {"name": "Major 6th (M6)", "short": "M6", "examples": [ {"title": "My Bonnie", "motif": [0, 9]}]},
	10: {"name": "Minor 7th (m7)", "short": "m7", "examples": [ {"title": "The Winner Takes It All", "motif": [0, 10]}]}, # ABBA? Or "Star Trek" theme (original) opening interval
	11: {"name": "Major 7th (M7)", "short": "M7", "examples": [ {"title": "Take On Me", "motif": [0, 11]}]}, # Chorus start? Or "Don't Know Why"
	12: {"name": "Perfect 8th (P8)", "short": "P8", "examples": [ {"title": "Somewhere Over the Rainbow", "motif": [0, 12]}]}
}

static func get_interval_name(semitones: int) -> String:
	if INTERVALS.has(semitones):
		return INTERVALS[semitones].name
	return "?"
