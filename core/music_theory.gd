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
const NOTE_NAMES_CDE := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_DOREMI := ["도", "도#", "레", "레#", "미", "파", "파#", "솔", "솔#", "라", "라#", "시"]

# ============================================================
# CONSTANTS - 스케일 & 코드
# ============================================================
const SCALE_INTERVALS := {
	ScaleMode.MAJOR: [0, 2, 4, 5, 7, 9, 11],
	ScaleMode.MINOR: [0, 2, 3, 5, 7, 8, 10]
}

const CHORD_INTERVALS := {
	"Maj7": [0, 4, 7, 11],
	"Dom7": [0, 4, 7, 10],
	"m7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10]
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
		KEY_1: [0, "Maj7", "I"],
		KEY_2: [2, "m7", "ii"],
		KEY_3: [4, "m7", "iii"],
		KEY_4: [5, "Maj7", "IV"],
		KEY_5: [7, "Dom7", "V"],
		KEY_6: [9, "m7", "vi"],
		KEY_7: [11, "m7b5", "vii°"]
	},
	ScaleMode.MINOR: {
		KEY_1: [0, "m7", "i"],
		KEY_2: [2, "m7b5", "ii°"],
		KEY_3: [3, "Maj7", "bIII"],
		KEY_4: [5, "m7", "iv"],
		KEY_5: [7, "m7", "v"],
		KEY_6: [8, "Maj7", "bVI"],
		KEY_7: [10, "Dom7", "bVII"]
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
		"Maj7": [[0, 0], [2, 1], [3, 1], [4, 0]],
		"Dom7": [[0, 0], [2, 0], [3, 1], [4, 0]],
		"m7": [[0, 0], [2, 0], [3, 0], [4, 0]],
		"m7b5": [[0, 0], [2, 0], [3, 0], [4, -1]]
	},
	"5th_string": {
		"Maj7": [[0, 0], [1, 2], [2, 1], [3, 2]],
		"Dom7": [[0, 0], [1, 2], [2, 0], [3, 2]],
		"m7": [[0, 0], [1, 2], [2, 0], [3, 1]],
		"m7b5": [[0, 0], [1, 1], [2, 0], [3, 1]]
	}
}

# ============================================================
# STATIC FUNCTIONS - 스케일 & 코드 판별
# ============================================================

## 해당 음이 스케일에 포함되는지 확인
static func is_in_scale(midi_note: int, key_root: int, mode: ScaleMode) -> bool:
	var interval := _get_interval(midi_note, key_root)
	return interval in SCALE_INTERVALS[mode]

## 3-Tier 시각화용 계층 반환 (1=Root, 2=ChordTone, 3=ScaleTone, 4=Avoid)
static func get_visual_tier(midi_note: int, chord_root: int, chord_type: String, key_root: int, mode: ScaleMode) -> int:
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
			return data[1] # "Maj7", "m7" 등
	
	return "Maj7" # 크로매틱 음에 대한 기본값

## Maj7 ↔ m7 토글 (Alt 키용)
static func toggle_quality(current_type: String) -> String:
	match current_type:
		"Maj7": return "m7"
		"m7": return "Maj7"
		"Dom7": return "m7"
		"m7b5": return "m7"
		_: return "Maj7"

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
	return "6th_string" if string_index == 0 else "5th_string"

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