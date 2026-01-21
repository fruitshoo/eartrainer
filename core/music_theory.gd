# music_theory.gd
class_name MusicTheory

enum NotationMode {CDE, DOREMI, BOTH}
enum ScaleMode {MAJOR, MINOR}

const CDE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const DOREMI_NAMES = ["도", "도#", "레", "레#", "미", "파", "파#", "솔", "솔#", "라", "라#", "시"]

const SCALE_INTERVALS = {
	ScaleMode.MAJOR: [0, 2, 4, 5, 7, 9, 11],
	ScaleMode.MINOR: [0, 2, 3, 5, 7, 8, 10]
}

const CHORD_TYPES = {
	"Maj7": [0, 4, 7, 11],
	"Dom7": [0, 4, 7, 10],
	"m7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10]
}

# [반음 오프셋, 코드 타입, 로마자 표기]
const CHORD_MAP = {
	ScaleMode.MAJOR: {
		KEY_1: {"normal": [0, "Maj7", "I"], "shift": [0, "Dom7", "V/IV"]},
		KEY_2: {"normal": [2, "m7", "ii"], "shift": [1, "Maj7", "bII"]},
		KEY_3: {"normal": [4, "m7", "iii"], "shift": [3, "Maj7", "bIII"]},
		KEY_4: {"normal": [5, "Maj7", "IV"], "shift": [5, "m7", "iv"]},
		KEY_5: {"normal": [7, "Dom7", "V"], "shift": [7, "m7", "v"]},
		KEY_6: {"normal": [9, "m7", "vi"], "shift": [8, "Maj7", "bVI"]}, # Gravity 코드!
		KEY_7: {"normal": [11, "m7b5", "vii"], "shift": [10, "Dom7", "bVII"]}
	},
	ScaleMode.MINOR: {
		KEY_1: {"normal": [0, "m7", "i"], "shift": [0, "Maj7", "I"]},
		KEY_2: {"normal": [2, "m7b5", "ii"], "shift": [1, "Maj7", "bII"]},
		KEY_3: {"normal": [3, "Maj7", "bIII"], "shift": [4, "m7", "iii"]},
		KEY_4: {"normal": [5, "m7", "iv"], "shift": [5, "Dom7", "IV"]},
		KEY_5: {"normal": [7, "m7", "v"], "shift": [7, "Dom7", "V7"]}, # 쿵쿵짝! 하모닉 V7
		KEY_6: {"normal": [8, "Maj7", "bVI"], "shift": [9, "m7b5", "vi"]},
		KEY_7: {"normal": [10, "Dom7", "bVII"], "shift": [11, "m7b5", "vii"]}
	}
}

static func get_chord_data(mode: ScaleMode, keycode: int, is_shift: bool) -> Array:
	if not CHORD_MAP[mode].has(keycode): return []
	var variant = "shift" if is_shift else "normal"
	return CHORD_MAP[mode][keycode][variant]

static func is_note_in_scale(midi_note: int, root: int, mode: ScaleMode) -> bool:
	var relative = (midi_note - root) % 12
	if relative < 0: relative += 12
	return relative in SCALE_INTERVALS[mode]

static func get_tier(midi_note: int, chord_root: int, chord_type: String, scale_root: int, mode: ScaleMode) -> int:
	var rel_chord = (midi_note - chord_root) % 12
	if rel_chord < 0: rel_chord += 12
	
	if rel_chord == 0: return 1 # Root
	if rel_chord in CHORD_TYPES[chord_type]: return 2 # Chord Tone
	if is_note_in_scale(midi_note, scale_root, mode): return 3 # Scale Tone
	return 4 # Non-Scale Tone