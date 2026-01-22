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

# 코드 폼 오프셋도 '더하기(+)' 방향으로 수정
const SHAPE_OFFSETS = {
	"6th_String_Root": {
		# GMaj7: 3 (R), X, 4 (7), 4 (3), 3 (5), X
		"Maj7": [[0, 0], [2, 1], [3, 1], [4, 0]],
		# G7 (Dom7): 3 (R), X, 3 (b7), 4 (3), 3 (5), X -> 연주자님이 요청하신 3-3-4-3!
		"Dom7": [[0, 0], [2, 0], [3, 1], [4, 0]],
		# Gm7: 3 (R), X, 3 (b7), 3 (b3), 3 (5), X
		"m7": [[0, 0], [2, 0], [3, 0], [4, 0]],
		# Gm7b5: 3 (R), X, 3 (b7), 3 (b3), 2 (b5), X
		"m7b5": [[0, 0], [2, 0], [3, 0], [4, -1]]
	},
	"5th_String_Root": {
		# CMaj7: X, 3 (R), 5 (5), 4 (7), 5 (3), X
		"Maj7": [[0, 0], [1, 2], [2, 1], [3, 2]],
		# C7 (Dom7): X, 3 (R), 5 (5), 3 (b7), 5 (3), X
		"Dom7": [[0, 0], [1, 2], [2, 0], [3, 2]],
		# Cm7: X, 3 (R), 5 (5), 3 (b7), 4 (b3), X
		"m7": [[0, 0], [1, 2], [2, 0], [3, 1]],
		# Cm7b5: X, 3 (R), 4 (b5), 3 (b7), 4 (b3), X
		"m7b5": [[0, 0], [1, 1], [2, 0], [3, 1]]
	}
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

# 반음 간격에 따른 도수 이름 맵
const DEGREE_NAMES = {
	ScaleMode.MAJOR: {
		0: "I", 1: "bII", 2: "ii", 3: "bIII", 4: "iii", 5: "IV",
		6: "#IV", 7: "V", 8: "bVI", 9: "vi", 10: "bVII", 11: "vii"
	},
	ScaleMode.MINOR: {
		0: "i", 1: "bII", 2: "ii°", 3: "bIII", 4: "iv", 5: "v",
		6: "bVI", 7: "V", 8: "bVI", 9: "vi°", 10: "bVII", 11: "vii°"
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

static func get_degree_label(root_note: int, key_root: int, mode: ScaleMode) -> String:
	var diff = (root_note - key_root) % 12
	if diff < 0: diff += 12
	return DEGREE_NAMES[mode].get(diff, "?")

# 1. 기타 개방현 미디 번호 (0: 1번줄 ~ 5: 6번줄 순서)
# [0:6번줄(E2), 1:5번줄(A2), 2:4번줄(D3), 3:3번줄(G3), 4:2번줄(B3), 5:1번줄(E4)]
const STRING_OPEN_NOTES = [40, 45, 50, 55, 59, 64]

# 2. 미디 번호를 받아서 특정 줄에서의 프렛 위치를 계산하는 함수
static func get_fret_pos(midi_note: int, string_idx: int) -> int:
	# (목표 미디 음 - 해당 줄의 개방현 음) = 프렛 번호
	var open_note = STRING_OPEN_NOTES[string_idx]
	return midi_note - open_note

static func get_smart_type_from_map(midi_note: int, key_root: int, mode: ScaleMode) -> String:
	var diff = (midi_note - key_root) % 12
	if diff < 0: diff += 12
	
	# CHORD_MAP을 순회하며 해당 반음 오프셋(diff)을 가진 데이터를 찾습니다.
	var current_mode_map = CHORD_MAP[mode]
	
	for key_id in current_mode_map:
		var chord_data = current_mode_map[key_id]["normal"] # 기본(normal) 세팅 참조
		if chord_data[0] == diff:
			return chord_data[1] # "Maj7", "m7" 등의 타입 반환
			
	# 만약 다이어토닉 외의 음(크로매틱 등)을 눌렀다면 기본적으로 Maj7을 반환하거나 
	# 현재 GameManager의 설정을 반환하도록 안전장치를 둡니다.
	return "Maj7"

# Shift 데이터 추출용 함수
static func get_shift_type_from_map(midi_note: int, key_root: int, mode: ScaleMode) -> String:
	var diff = (midi_note - key_root) % 12
	if diff < 0: diff += 12
	
	var current_mode_map = CHORD_MAP[mode]
	
	# CHORD_MAP의 각 항목(KEY_1, KEY_2 등)을 순회하며 'normal'의 오프셋과 비교
	for key_enum in current_mode_map:
		var data = current_mode_map[key_enum]
		if data["normal"][0] == diff:
			var shift_type = data["shift"][1]
			print("Shift 매칭 성공! 도수 반음:", diff, " 타입:", shift_type)
			return shift_type
			
	return "Dom7" # 찾지 못했을 때의 기본값

# 메이저/마이너 스왑 함수 (Alt 키 대응)
static func toggle_maj_min(current_type: String) -> String:
	match current_type:
		"Maj7": return "m7"
		"m7": return "Maj7"
		"Dom7": return "m7" # 도미넌트는 보통 마이너로 스왑
		"m7b5": return "m7"
		_: return "Maj7"