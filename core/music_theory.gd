# music_theory.gd
# 음악 이론 상수 및 유틸리티 함수 (정적 클래스)
class_name MusicTheory

# ============================================================
# ENUMS
# ============================================================
enum NotationMode {CDE, DOREMI, BOTH, DEGREE}
enum ScaleMode {
	MAJOR,
	MINOR,
	DORIAN,
	PHRYGIAN,
	LYDIAN,
	MIXOLYDIAN,
	LOCRIAN,
	MAJOR_PENTATONIC,
	MINOR_PENTATONIC
}

enum ChordPlaybackMode {ONCE, BEAT, HALF_BEAT}

# ============================================================
# CONSTANTS - 음이름
# ============================================================
const NOTE_NAMES_SHARP: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT: Array[String] = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
const NOTE_NAMES_CDE: Array[String] = NOTE_NAMES_SHARP
const NOTE_NAMES_DOREMI_SHARP: Array[String] = ["도", "도#", "레", "레#", "미", "파", "파#", "솔", "솔#", "라", "라#", "시"]
const NOTE_NAMES_DOREMI_FLAT: Array[String] = ["도", "레b", "레", "미b", "미", "파", "솔b", "솔", "라b", "라", "시b", "시"]
const NOTE_NAMES_DOREMI: Array[String] = NOTE_NAMES_DOREMI_SHARP

# ============================================================
# CONSTANTS - 스케일 & 코드
# ============================================================
const SCALE_DATA := {
	ScaleMode.MAJOR: {
		"name": "Major (Ionian)",
		"intervals": [0, 2, 4, 5, 7, 9, 11],
		"category": "Diatonic",
		"parent_mode": null
	},
	ScaleMode.MINOR: {
		"name": "Minor (Aeolian)",
		"intervals": [0, 2, 3, 5, 7, 8, 10],
		"category": "Diatonic",
		"parent_mode": null
	},
	ScaleMode.DORIAN: {
		"name": "Dorian",
		"intervals": [0, 2, 3, 5, 7, 9, 10],
		"category": "Modes",
		"parent_mode": null
	},
	ScaleMode.PHRYGIAN: {
		"name": "Phrygian",
		"intervals": [0, 1, 3, 5, 7, 8, 10],
		"category": "Modes",
		"parent_mode": null
	},
	ScaleMode.LYDIAN: {
		"name": "Lydian",
		"intervals": [0, 2, 4, 6, 7, 9, 11],
		"category": "Modes",
		"parent_mode": null
	},
	ScaleMode.MIXOLYDIAN: {
		"name": "Mixolydian",
		"intervals": [0, 2, 4, 5, 7, 9, 10],
		"category": "Modes",
		"parent_mode": null
	},
	ScaleMode.LOCRIAN: {
		"name": "Locrian",
		"intervals": [0, 1, 3, 5, 6, 8, 10],
		"category": "Modes",
		"parent_mode": null
	},
	ScaleMode.MAJOR_PENTATONIC: {
		"name": "Major Pentatonic",
		"intervals": [0, 2, 4, 7, 9],
		"category": "Pentatonic",
		"parent_mode": ScaleMode.MAJOR
	},
	ScaleMode.MINOR_PENTATONIC: {
		"name": "Minor Pentatonic",
		"intervals": [0, 3, 5, 7, 10],
		"category": "Pentatonic",
		"parent_mode": ScaleMode.MINOR
	}
}

# [Backward Compatibility] Shortcut for old dict access style
static func _get_scale_intervals(mode: ScaleMode) -> Array:
	return SCALE_DATA[mode]["intervals"]

const CHORD_INTERVALS := {
	"M": [0, 4, 7],
	"m": [0, 3, 7],
	"M7": [0, 4, 7, 11],
	"7": [0, 4, 7, 10],
	"m7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10],
	"5": [0, 7, 12], # Power Chord (Root, 5th, Octave)
	# Extensions
	"add9": [0, 4, 7, 14],
	"m9": [0, 3, 7, 10, 14],
	# Suspended
	"sus4": [0, 5, 7],
	"7sus4": [0, 5, 7, 10],
	# Alterations
	"dim7": [0, 3, 6, 9],
	"aug": [0, 4, 8],
	# Slash / Inversions
	"M/2": [0, 2, 4, 7], # Hybrid (IV/V form)
	"M/3": [0, 2, 4, 7] # 1st Inv (add9 form)
}


# ============================================================
# CONSTANTS - 기타 튜닝 (인덱스 0 = 6번줄)
# ============================================================
const OPEN_STRING_MIDI := [40, 45, 50, 55, 59, 64]

# ============================================================
# CONSTANTS - 다이어토닉 매핑 (키보드 입력용)
# ============================================================
# DIATONIC_MAP removed (Replaced by Dynamic Generation)

# ============================================================
# CONSTANTS - 도수 레이블 (시퀀서 UI용 - 로마자)
# ============================================================
const DEGREE_LABELS := {
	ScaleMode.MAJOR: {
		0: "I", 1: "bII", 2: "ii", 3: "bIII", 4: "iii", 5: "IV",
		6: "#IV", 7: "V", 8: "bVI", 9: "vi", 10: "bVII", 11: "vii°"
	},
	ScaleMode.MINOR: {
		0: "i", 1: "bII", 2: "ii°", 3: "bIII", 4: "III", 5: "iv",
		6: "#iv", 7: "v", 8: "bVI", 9: "VI", 10: "bVII", 11: "vii°"
	}
}

# ============================================================
# CONSTANTS - 도수 레이블 (NotationMode.DEGREE 용 - 숫자)
# ============================================================
const DEGREE_NUMBERS = {
	0: "1", 1: "b2", 2: "2", 3: "b3", 4: "3", 5: "4",
	6: "b5", 7: "5", 8: "b6", 9: "6", 10: "b7", 11: "7"
}

# ============================================================
# CONSTANTS - 코드 보이싱 (시퀀서 스트럼용)
# ============================================================
const VOICING_SHAPES := {
	"6th_string": {
		"M": [[0, 0], [1, 2], [2, 2], [3, 1], [4, 0], [5, 0]],
		"m": [[0, 0], [1, 2], [2, 2], [3, 0], [4, 0], [5, 0]],
		"M7": [[0, 0], [2, 1], [3, 1], [4, 0]],
		"7": [[0, 0], [2, 0], [3, 1], [4, 0]],
		"m7": [[0, 0], [2, 0], [3, 0], [4, 0]],
		"m7b5": [[0, 0], [2, 0], [3, 0], [4, -1]],
		"5": [[0, 0], [1, 2], [2, 2]], # Standard 3-note power chord (R, 5, 8)
		
		"add9": [[0, 0], [2, 1], [3, 2], [4, 0]],
		"m9": [[0, 0], [2, 0], [3, 0], [4, 2]],
		"sus4": [[0, 0], [2, 2], [3, 2], [4, 0]],
		"7sus4": [[0, 0], [2, 0], [3, 2], [4, 0]],
		"dim7": [[0, 0], [2, -1], [3, -1], [4, -1]], # Root on 6th? Dim7 shape usually requires skipping strings or awkward stretch. Simplified block.
		"aug": [[0, 0], [2, 1], [3, 1], [4, 1]], # Augmented
		
		"M/2": [[0, 2], [2, 2], [3, 1], [4, 0]], # G/A form (5x543x => Bass+2, Root+2, 3rd+1, 5th+0).
		
		"M/3": [[0, 4], [2, 4], [3, 4], [4, 5]] # E/G# form (Bass+4, 9th, 5th, Root)
	},

	"5th_string": {
		"M": [[0, 0], [1, 2], [2, 2], [3, 2], [4, 0]],
		"m": [[0, 0], [1, 2], [2, 2], [3, 1], [4, 0]],
		"M7": [[0, 0], [1, 2], [2, 1], [3, 2]],
		"7": [[0, 0], [1, 2], [2, 0], [3, 2]],
		"m7": [[0, 0], [1, 2], [2, 0], [3, 1]],
		"m7b5": [[0, 0], [1, 1], [2, 0], [3, 1]],
		"5": [[0, 0], [1, 2], [2, 2]], # Standard 3-note power chord (R, 5, 8)
		
		"add9": [[0, 0], [1, 2], [2, 2], [3, 0]], # x5775x (R, 5, R, 9) - User requested form
		"m9": [[0, 0], [1, 2], [2, 0], [3, 3]],
		"sus4": [[0, 0], [1, 2], [2, 2], [3, 3]], # A string root sus4
		"7sus4": [[0, 0], [1, 2], [2, 0], [3, 3]],
		"dim7": [[0, 0], [1, 1], [2, -1], [3, 1]],
		"aug": [[0, 0], [1, 2], [2, 1], [3, 2]] # Same as M7 but #5?
		
		# M/2 and M/3 are only valid for 6th string root (currently)
	},

	"4th_string": {
		"M": [[0, 0], [1, 2], [2, 3], [3, 2]],
		"m": [[0, 0], [1, 2], [2, 3], [3, 1]],
		"M7": [[0, 0], [1, 2], [2, 2], [3, 2]], # R(4), 5(3), 7(2), 3(1)
		"7": [[0, 0], [1, 2], [2, 1], [3, 2]], # R(4), 5(3), b7(2), 3(1)
		"m7": [[0, 0], [1, 2], [2, 1], [3, 1]], # R(4), 5(3), b7(2), b3(1)
		"m7b5": [[0, 0], [1, 1], [2, 1], [3, 1]], # R(4), b5(3), b7(2), b3(1)
		"5": [[0, 0], [1, 2], [2, 3]], # R(4), 5(3), 8(2) - Note 2nd string compensation (+1 fret)
	}
}

# ============================================================
# STATIC FUNCTIONS - 음이름 & 표기법
# ============================================================

## 현재 키/모드에 따라 Flat 표기를 사용할지 결정
static func should_use_flats(key_root: int, mode: ScaleMode) -> bool:
	var root_index := key_root % 12
	if mode == ScaleMode.MAJOR:
		# F(5), Bb(10), Eb(3), Ab(8), Db(1) Major -> Flat
		# F#(6) is now treated as Sharp based on user preference
		return root_index in [1, 3, 5, 8, 10]
	else:
		# C(0), D(2), Eb(3), F(5), G(7), Bb(10) Minor -> Flat
		# (Note: Minor keys relative to Major flat keys)
		return root_index in [0, 2, 3, 5, 7, 10]

## MIDI 노트 번호에 해당하는 음이름 반환 (Flat/Sharp 자동 처리)
static func get_note_name(midi_note: int, use_flats: bool = false) -> String:
	var index := midi_note % 12
	if use_flats:
		return NOTE_NAMES_FLAT[index]
	return NOTE_NAMES_SHARP[index]

## DoReMi 표기법 반환 (Flat/Sharp 자동 처리)
static func get_doremi_name(relative_note: int, use_flats: bool = false) -> String:
	var index := relative_note % 12
	# 음수 인덱스 처리
	if index < 0: index += 12
		
	if use_flats:
		return NOTE_NAMES_DOREMI_FLAT[index]
	return NOTE_NAMES_DOREMI_SHARP[index]

## 숫자 기반 도수 표기 (1, b2, 2, b3...) 반환
static func get_degree_number_name(midi_note: int, key_root: int) -> String:
	var interval := _get_interval(midi_note, key_root)
	return DEGREE_NUMBERS.get(interval, "?")

## 해당 음이 스케일에 포함되는지 확인
static func is_in_scale(midi_note: int, key_root: int, mode: ScaleMode) -> bool:
	# Safety: Check for invalid mode before accessing SCALE_DATA
	if mode == -1 or not mode in SCALE_DATA:
		return false
	
	var interval := _get_interval(midi_note, key_root)
	return interval in SCALE_DATA[mode]["intervals"]

## 3-Tier 시각화용 계층 반환 (1=Root, 2=ChordTone, 3=ScaleTone, 4=Avoid)
static func get_visual_tier(midi_note: int, chord_root: int, chord_type: String, key_root: int, mode: ScaleMode) -> int:
	# [DEBUG] 값 추적 - 문제 해결 후 삭제할 것
	var chord_interval := _get_interval(midi_note, chord_root)
	
	if chord_interval == 0:
		return 1 # Root
	if chord_interval in CHORD_INTERVALS.get(chord_type, []):
		return 2 # Chord Tone
	if is_in_scale(midi_note, key_root, mode):
		return 3 # Scale Tone
	return 4 # Avoid Note

# ============================================================
# STATIC FUNCTIONS - 다이어토닉 타입 추론
# ============================================================

## 클릭한 음의 다이어토닉 코드 타입 자동 추론 (Dynamic)
static func get_diatonic_type(midi_note: int, key_root: int, mode: ScaleMode) -> String:
	# 1. Determine which mode to use for chords (Parent vs Self)
	var chord_mode = mode
	var parent_mode = SCALE_DATA[mode].get("parent_mode")
	if parent_mode != null:
		chord_mode = parent_mode
		
	# 2. Get Intervals
	var intervals = SCALE_DATA[chord_mode]["intervals"]
	var target_interval := _get_interval(midi_note, key_root)
	
	# 3. Check if the note is a scale tone
	var degree_idx = intervals.find(target_interval)
	if degree_idx == -1:
		return "M7" # Non-diatonic (Chromatic) root -> Default to M7
		
	# 4. Stack Thirds to determine quality
	# Scale degrees (0-based index in intervals array)
	var third_idx = (degree_idx + 2) % intervals.size()
	var fifth_idx = (degree_idx + 4) % intervals.size()
	var seventh_idx = (degree_idx + 6) % intervals.size()
	
	var root_val = intervals[degree_idx]
	var third_val = intervals[third_idx]
	var fifth_val = intervals[fifth_idx]
	var seventh_val = intervals[seventh_idx]
	
	# Adjust for octave wrapping
	if third_idx < degree_idx: third_val += 12
	if fifth_idx < degree_idx: fifth_val += 12
	if seventh_idx < degree_idx: seventh_val += 12
	
	var dist_third = third_val - root_val
	var dist_fifth = fifth_val - root_val
	var dist_seventh = seventh_val - root_val
	
	# Analyze Triad & Seventh
	if dist_third == 4: # Major 3rd
		if dist_fifth == 7: # Perfect 5th
			if dist_seventh == 11: return "M7"
			else: return "7" # b7
		elif dist_fifth == 8: # Augmented 5th
			return "aug"
	elif dist_third == 3: # Minor 3rd
		if dist_fifth == 7: # Perfect 5th
			if dist_seventh == 11: return "mM7" # Rare but exists
			else: return "m7"
		elif dist_fifth == 6: # Diminished 5th
			if dist_seventh == 9: return "dim7" # Full Dim
			else: return "m7b5" # Half Dim (b7)
			
	return "M7" # Fallback

## Maj7 ↔ m7 토글 (Alt 키용)
static func toggle_quality(current_type: String) -> String:
	match current_type:
		"M7": return "m7"
		"m7": return "M7"
		"7": return "m7"
		"m7b5": return "m7"
		_: return "M7"

# ============================================================
# STATIC FUNCTIONS - 도수 레이블
# ============================================================

## 반음 간격으로 로마 숫자 도수 반환
static func get_degree_label(chord_root: int, key_root: int, mode: ScaleMode) -> String:
	var interval := _get_interval(chord_root, key_root)
	return DEGREE_LABELS[mode].get(interval, "?")

# ============================================================
# STATIC FUNCTIONS - 기타 유틸리티
# ============================================================

## 특정 줄에서의 프렛 위치 계산
static func get_fret_position(midi_note: int, string_index: int) -> int:
	return midi_note - OPEN_STRING_MIDI[string_index]

## 루트 줄 번호로 보이싱 키 반환
static func get_voicing_key(string_index: int) -> String:
	match string_index:
		0: return "6th_string"
		1: return "5th_string"
		2: return "4th_string"
		_: return "6th_string" # Default fallback

## 키보드 입력 → 코드 데이터 반환 (game_manager용)
## 키보드 입력 → 코드 데이터 반환 (game_manager용)
static func get_chord_from_keycode(mode: ScaleMode, keycode: int) -> Array:
	var degree_idx = -1
	match keycode:
		KEY_1: degree_idx = 0
		KEY_2: degree_idx = 1
		KEY_3: degree_idx = 2
		KEY_4: degree_idx = 3
		KEY_5: degree_idx = 4
		KEY_6: degree_idx = 5
		KEY_7: degree_idx = 6
	
	if degree_idx == -1: return []
	
	# Determine Chord Mode (Parent vs Self)
	var chord_mode = mode
	var parent_mode = SCALE_DATA[mode].get("parent_mode")
	if parent_mode != null:
		chord_mode = parent_mode
		
	var intervals = SCALE_DATA[chord_mode]["intervals"]
	if degree_idx >= intervals.size(): return []
	
	var interval = intervals[degree_idx]
	var type = get_diatonic_type(interval, 0, chord_mode) # Pass 0 as root to simulate relative check
	
	# Generate Roman Numeral (Simplified for now)
	var roman = DEGREE_LABELS.get(chord_mode, DEGREE_LABELS[ScaleMode.MAJOR]).get(interval, "?")
	
	return [interval, type, roman]

# ============================================================
# PRIVATE HELPER
# ============================================================

static func _get_interval(midi_note: int, root: int) -> int:
	var interval := (midi_note - root) % 12
	return interval + 12 if interval < 0 else interval

## 특정 줄(String)에 해당 코드 타입의 보이싱이 존재하는지 확인
static func has_voicing(type: String, string_index: int) -> bool:
	var voicing_key = get_voicing_key(string_index)
	var shapes = VOICING_SHAPES.get(voicing_key, {})
	return shapes.has(type)

## 코드 탭 문자열 생성 (예: "x32010")
static func get_tab_string(root: int, type: String, string_index: int) -> String:
	var voicing_key = get_voicing_key(string_index)
	var shapes = VOICING_SHAPES.get(voicing_key, {}).get(type, [])
	
	if shapes.is_empty():
		return "x-x-x-x-x-x"
		
	# Init 6 strings with 'x'
	var tabs = ["x", "x", "x", "x", "x", "x"]
	
	# root fret calculation
	var root_fret = get_fret_position(root, string_index)
	
	for offset in shapes:
		var target_string_idx = string_index + offset[0]
		var target_fret = root_fret + offset[1]
		
		# String index in array (Godot project logic seems to use 0 for 6th string?)
		# Mapping: 0(6th) -> tabs[0]
		if target_string_idx >= 0 and target_string_idx < 6:
			tabs[target_string_idx] = str(target_fret)
			
	return "".join(tabs)
