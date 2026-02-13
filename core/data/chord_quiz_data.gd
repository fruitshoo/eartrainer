class_name ChordQuizData
extends RefCounted

# Chord Definitions
const CHORDS = {
	# Tier 1: Triads
	"maj": {"name": "Major", "intervals": [0, 4, 7], "tier": 1},
	"min": {"name": "Minor", "intervals": [0, 3, 7], "tier": 1},
	
	# Tier 2: Basic 7ths
	"maj7": {"name": "Major 7th", "intervals": [0, 4, 7, 11], "tier": 2},
	"min7": {"name": "Minor 7th", "intervals": [0, 3, 7, 10], "tier": 2},
	"dom7": {"name": "Dominant 7th", "intervals": [0, 4, 7, 10], "tier": 2},
	
	# Tier 3: Extensions / Altered
	"m7b5": {"name": "Minor 7th Flat 5", "intervals": [0, 3, 6, 10], "tier": 3},
	"dim7": {"name": "Diminished 7th", "intervals": [0, 3, 6, 9], "tier": 3},
	# "aug": { "name": "Augmented", "intervals": [0, 4, 8], "tier": 3 } # Optional
}

static func get_chord_info(type: String) -> Dictionary:
	return CHORDS.get(type, {})

static func get_chord_intervals(type: String) -> Array:
	return CHORDS.get(type, {}).get("intervals", [])
