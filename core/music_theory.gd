# music_theory.gd
# 음악 이론 상수 및 유틸리티 함수 (정적 클래스)
class_name MusicTheory

# ============================================================
# ENUMS
# ============================================================
enum NotationMode {CDE, DOREMI, BOTH}
enum ScaleMode {MAJOR, MINOR}

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
const SCALE_INTERVALS := {
	ScaleMode.MAJOR: [0, 2, 4, 5, 7, 9, 11],
	ScaleMode.MINOR: [0, 2, 3, 5, 7, 8, 10]
}

const CHORD_INTERVALS := {
	"M7": [0, 4, 7, 11],
	"7": [0, 4, 7, 10],
	"m7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10],
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
const DIATONIC_MAP := {
	ScaleMode.MAJOR: {
		KEY_1: [0, "M7", "I"],
		KEY_2: [2, "m7", "ii"],
		KEY_3: [4, "m7", "iii"],
		KEY_4: [5, "M7", "IV"],
		KEY_5: [7, "7", "V"],
		KEY_6: [9, "m7", "vi"],
		KEY_7: [11, "m7b5", "vii°"]
	},
	ScaleMode.MINOR: {
		KEY_1: [0, "m7", "i"],
		KEY_2: [2, "m7b5", "ii°"],
		KEY_3: [3, "M7", "bIII"],
		KEY_4: [5, "m7", "iv"],
		KEY_5: [7, "m7", "v"],
		KEY_6: [8, "M7", "bVI"],
		KEY_7: [10, "7", "bVII"]
	}
}

# ============================================================
# CONSTANTS - 도수 레이블 (시퀀서 UI용)
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
# CONSTANTS - 코드 보이싱 (시퀀서 스트럼용)
# ============================================================
const VOICING_SHAPES := {
	"6th_string": {
		"M7": [[0, 0], [2, 1], [3, 1], [4, 0]],
		"7": [[0, 0], [2, 0], [3, 1], [4, 0]],
		"m7": [[0, 0], [2, 0], [3, 0], [4, 0]],
		"m7b5": [[0, 0], [2, 0], [3, 0], [4, -1]],
		
		"add9": [[0, 0], [2, 1], [3, 2], [4, 0]],
		"m9": [[0, 0], [2, 0], [3, 0], [4, 2]],
		"sus4": [[0, 0], [2, 2], [3, 2], [4, 0]],
		"7sus4": [[0, 0], [2, 0], [3, 2], [4, 0]],
		"dim7": [[0, 0], [2, -1], [3, -1], [4, -1]], # Root on 6th? Dim7 shape usually requires skipping strings or awkward stretch. Simplified block.
		"aug": [[0, 0], [2, 1], [3, 1], [4, 1]], # Augmented
		
		"M/2": [[0, 2], [2, 2], [3, 1], [4, 0]], # G/A form (5x543x => Bass+2, Root+2, 3rd+1, 5th+0).
		# Logic check:
		# Root G (3rd fret). Bass A (5th fret, +2).
		# D str G (5th fret, +2 from F? No. Relative to 6th str root).
		# If Root is 6th str (index 0). Offset [0, y].
		# Root G -> Fret 3.
		# Str 6 (Bass): Fret 5 (A). Offset +2? Yes. `[0, 2]`.
		# Str 5 (Mute).
		# Str 4 (D str): Fret 5 (G). Root.
		#   If Root G (6th str/3rd fret).
		#   D str Open is D. G is 5th fret.
		#   Root fret for 4th string? 
		#     If I use get_fret_position(root, 4) -> It returns fret for G on D string? -> 5.
		#     So offset from "Root Fret on target string"?
		#     Wait. `MusicTheory.get_tab_string`: `root_fret = get_fret_position(root, string_index)`
		#     This calculates root fret relative to the *Voicing Key String* (string_index).
		#     If `voicing_key` is `6th_string`, then `string_index` passed to `get_tab_string` must be 0?
		#     Yes, `_add_chord_item` passes `string_idx` from slot data.
		#     If slot is 6th string root, `string_idx` is 0.
		#     So `root_fret` is calculated for 6th string.
		#     Then loop `target_fret = root_fret + offset[1]`.
		#     Wait. `offset[1]` is added to `root_fret` (which is on 6th string!).
		#     But the target note is on `target_string_idx`.
		#     Does `root_fret` (on 6th string) make sense as a base for other strings?
		#     ONLY if the offsets are defined relative to that fret number across the board.
		#     Ex: 5th fret Barre chord. Root is 5th fret.
		#     Str 6: 5 (Offset 0).
		#     Str 5: 7 (Offset 2).
		#     Str 4: 7 (Offset 2).
		#     Str 3: 6 (Offset 1).
		#     This assumes "Fret 5" is the base.
		#     So yes, my offsets `[[0, 2], [2, 2], [3, 1], [4, 0]]` mean:
		#       Str 6: RootFret + 2.
		#       Str 4: RootFret + 2.
		#       Str 3: RootFret + 1.
		#       Str 2: RootFret + 0.
		#     If Root G is Fret 3.
		#       Str 6: 5 (A). Correct.
		#       Str 4: 5 (G). Correct.
		#       Str 3: 4 (B). Correct.
		#       Str 2: 3 (D). Correct.
		#     This matches 5x543 perfectly.
		
		"M/3": [[0, 4], [2, 4], [3, 4], [4, 5]] # E/G# form (Bass+4, 9th, 5th, Root)
	},

	"5th_string": {
		"M7": [[0, 0], [1, 2], [2, 1], [3, 2]],
		"7": [[0, 0], [1, 2], [2, 0], [3, 2]],
		"m7": [[0, 0], [1, 2], [2, 0], [3, 1]],
		"m7b5": [[0, 0], [1, 1], [2, 0], [3, 1]],
		
		"add9": [[0, 0], [1, 2], [2, 2], [3, 0]], # x5775x (R, 5, R, 9) - User requested form
		"m9": [[0, 0], [1, 2], [2, 0], [3, 3]],
		"sus4": [[0, 0], [1, 2], [2, 2], [3, 3]], # A string root sus4
		"7sus4": [[0, 0], [1, 2], [2, 0], [3, 3]],
		"dim7": [[0, 0], [1, 1], [2, -1], [3, 1]],
		"aug": [[0, 0], [1, 2], [2, 1], [3, 2]] # Same as M7 but #5?
		
		# M/2 and M/3 are only valid for 6th string root (currently)
	},

	"4th_string": {
		"M7": [[0, 0], [1, 2], [2, 2], [3, 2]], # R(4), 5(3), 7(2), 3(1)
		"7": [[0, 0], [1, 2], [2, 1], [3, 2]], # R(4), 5(3), b7(2), 3(1)
		"m7": [[0, 0], [1, 2], [2, 1], [3, 1]], # R(4), 5(3), b7(2), b3(1)
		"m7b5": [[0, 0], [1, 1], [2, 1], [3, 1]] # R(4), b5(3), b7(2), b3(1)
	}
}

# ============================================================
# STATIC FUNCTIONS - 음이름 & 표기법
# ============================================================

## 현재 키/모드에 따라 Flat 표기를 사용할지 결정
static func should_use_flats(key_root: int, mode: ScaleMode) -> bool:
	var root_index := key_root % 12
	if mode == ScaleMode.MAJOR:
		# F(5), Bb(10), Eb(3), Ab(8), Db(1), Gb(6) Major -> Flat
		return root_index in [1, 3, 5, 6, 8, 10]
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

## 해당 음이 스케일에 포함되는지 확인
static func is_in_scale(midi_note: int, key_root: int, mode: ScaleMode) -> bool:
	var interval := _get_interval(midi_note, key_root)
	return interval in SCALE_INTERVALS[mode]

## 3-Tier 시각화용 계층 반환 (1=Root, 2=ChordTone, 3=ScaleTone, 4=Avoid)
static func get_visual_tier(midi_note: int, chord_root: int, chord_type: String, key_root: int, mode: ScaleMode) -> int:
	# [DEBUG] 값 추적 - 문제 해결 후 삭제할 것
	# print("get_visual_tier -> Note:%d ChordRoot:%d Type:%s KeyRoot:%d Mode:%d" % [midi_note, chord_root, chord_type, key_root, mode])
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

## 클릭한 음의 다이어토닉 코드 타입 자동 추론
static func get_diatonic_type(midi_note: int, key_root: int, mode: ScaleMode) -> String:
	var interval := _get_interval(midi_note, key_root)
	
	for key_code in DIATONIC_MAP[mode]:
		var data: Array = DIATONIC_MAP[mode][key_code]
		if data[0] == interval:
			return data[1] # "M7", "m7" 등
	
	return "M7" # 크로매틱 음에 대한 기본값

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
static func get_chord_from_keycode(mode: ScaleMode, keycode: int) -> Array:
	if DIATONIC_MAP[mode].has(keycode):
		return DIATONIC_MAP[mode][keycode]
	return []

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
		# Let's verify string indexing in audio_engine or tile.
		# Usually standard is 0=Low E (6th), 5=High e (1st).
		
		# Mapping:
		# 0(6th) -> tabs[0]
		if target_string_idx >= 0 and target_string_idx < 6:
			tabs[target_string_idx] = str(target_fret)
			
	# Return formatted string (Low to High? or Standard Tab High to Low?)
	# Text representation usually "3x0003" (Low E to High e) for single line text.
	return "".join(tabs)