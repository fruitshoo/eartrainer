class_name ChordQuizData
extends RefCounted

# Chord Definitions
const CHORD_QUALITIES = {
	"Major": [0, 4, 7],
	"Minor": [0, 3, 7],
	"Diminished": [0, 3, 6],
	"Augmented": [0, 4, 8],
	"Maj7": [0, 4, 7, 11],
	"min7": [0, 3, 7, 10],
	"Dom7": [0, 4, 7, 10],
	"m7b5": [0, 3, 6, 10],
	"dim7": [0, 3, 6, 9],
	"Power": [0, 7] # [New]
}

# [New] Common Diatonic Progressions (Indices: 0=I, 1=ii, 2=iii, 3=IV, 4=V, 5=vi, 6=vii)
const DIATONIC_PROGRESSIONS = {
	"Pop 1 (I-V-vi-IV)": [0, 4, 5, 3],
	"Pop 2 (I-vi-IV-V)": [0, 5, 3, 4], # Doo-wop / 50s
	"Pop 3 (vi-IV-I-V)": [5, 3, 0, 4], # "Sensitive Female" / Emotional
	"Jazz (ii-V-I)": [1, 4, 0],
	"Jazz (I-vi-ii-V)": [0, 5, 1, 4],
	"Rock (I-IV-V)": [0, 3, 4],
	"Rock (I-V-IV)": [0, 4, 3],
	"Ballad (I-iii-IV-V)": [0, 2, 3, 4],
	"Standard (I-IV-I-V)": [0, 3, 0, 4],
	"Minor 1 (i-VI-III-VII)": [0, 5, 2, 6], # Aeolian
	"Minor 2 (i-iv-v)": [0, 3, 4],
	"Circle (vi-ii-V-I)": [5, 1, 4, 0],
}

# [New] Functional Harmony Transition Rules (Markov Chain)
# Defines musically pleasing "next chords" for any given diatonic degree (0=I, 1=ii, 2=iii, 3=IV, 4=V, 5=vi, 6=vii)
const DIATONIC_TRANSITIONS = {
	0: [3, 4, 5, 1, 2], # I -> IV, V, vi, ii, iii (Can go anywhere)
	1: [4, 6, 5], # ii -> V (strongest), vii°, vi
	2: [5, 3, 1], # iii -> vi, IV, ii
	3: [4, 0, 1], # IV -> V, I, ii
	4: [0, 5], # V -> I (resolution), vi (deceptive)
	5: [3, 1, 4], # vi -> IV, ii, V
	6: [0, 2] # vii° -> I, iii
}

# Original CHORDS constant (modified to use CHORD_QUALITIES for intervals)
const CHORDS = {
	# Tier 1: Triads
	"maj": {"name": "Major", "intervals": CHORD_QUALITIES.Major, "tier": 1},
	"min": {"name": "Minor", "intervals": CHORD_QUALITIES.Minor, "tier": 1},
	
	# Tier 2: Basic 7ths
	"M7": {"name": "Major 7th", "intervals": CHORD_QUALITIES.Maj7, "tier": 2},
	"m7": {"name": "Minor 7th", "intervals": CHORD_QUALITIES.min7, "tier": 2},
	"7": {"name": "Dominant 7th", "intervals": CHORD_QUALITIES.Dom7, "tier": 2},
	
	# Tier 3: Extensions / Altered
	"m7b5": {"name": "Minor 7th Flat 5", "intervals": [0, 3, 6, 10], "tier": 3},
	"dim7": {"name": "Diminished 7th", "intervals": [0, 3, 6, 9], "tier": 3},
	# "aug": { "name": "Augmented", "intervals": [0, 4, 8], "tier": 3 } # Optional
}

static func get_chord_info(type: String) -> Dictionary:
	return CHORDS.get(type, {})

static func get_chord_intervals(type: String) -> Array:
	return CHORDS.get(type, {}).get("intervals", [])
