extends Node

signal settings_changed
signal player_moved

enum NotationMode {CDE, DOREMI, BOTH}
enum ScaleMode {MAJOR, MINOR} # 모드 추가

# --- 게임 상태 변수 ---
var current_root_note: int = 0:
	set(value):
		current_root_note = value
		current_chord_root = value
		settings_changed.emit()

var current_scale_mode: ScaleMode = ScaleMode.MAJOR:
	set(value):
		current_scale_mode = value
		
		# 모드가 바뀌면 그 모드에 맞는 '1도 코드'로 강제 동기화
		if value == ScaleMode.MAJOR:
			current_chord_type = "Maj7"
		else:
			current_chord_type = "m7"
		
		# 근음도 현재 키의 1도로 리셋 (코드와 키가 따로 노는 현상 방지)
		current_chord_root = current_root_note
		
		# 이 신호가 발생하면서 타일들과 HUD가 일제히 업데이트됩니다.
		settings_changed.emit()

var current_notation: NotationMode = NotationMode.BOTH:
	set(value):
		current_notation = value
		settings_changed.emit()

var is_hint_visible: bool = false:
	set(value):
		is_hint_visible = value
		settings_changed.emit()

var current_chord_type: String = "Maj7":
	set(value):
		current_chord_type = value
		settings_changed.emit()

var current_chord_root: int = 0:
	set(value):
		current_chord_root = value
		settings_changed.emit()

# 캐릭터 관련
var current_player: Node3D = null
var player_fret: int = 0:
	set(value):
		if player_fret != value:
			player_fret = value
			player_moved.emit()

var focus_range: int = 3
var settings_ui_ref: CanvasLayer = null

# --- 음악 데이터 ---
const CDE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const DOREMI_NAMES = ["도", "도#", "레", "레#", "미", "파", "파#", "솔", "솔#", "라", "라#", "시"]

const MAJOR_SCALE_INTERVALS = [0, 2, 4, 5, 7, 9, 11]
const MINOR_SCALE_INTERVALS = [0, 2, 3, 5, 7, 8, 10] # 내추럴 마이너 (1, 2, b3, 4, 5, b6, b7)

const CHORD_TYPES = {
	"Maj7": [0, 4, 7, 11],
	"Dom7": [0, 4, 7, 10],
	"m7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10]
}

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_settings()
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M: # 모드 전환
				if current_scale_mode == ScaleMode.MAJOR:
					current_scale_mode = ScaleMode.MINOR
					current_chord_type = "m7"
				else:
					current_scale_mode = ScaleMode.MAJOR
					current_chord_type = "Maj7"

			# --- 다이어토닉 코드 매핑 ---
			KEY_1: # I도 / i도
				current_chord_root = current_root_note
				current_chord_type = "Maj7" if current_scale_mode == ScaleMode.MAJOR else "m7"
				
			KEY_2: # ii도 / ii도
				current_chord_root = (current_root_note + 2) % 12
				current_chord_type = "m7" if current_scale_mode == ScaleMode.MAJOR else "m7b5"
				
			KEY_3: # iii도 / bIII도
				if current_scale_mode == ScaleMode.MAJOR:
					current_chord_root = (current_root_note + 4) % 12
					current_chord_type = "m7"
				else:
					current_chord_root = (current_root_note + 3) % 12 # b3 위치
					current_chord_type = "Maj7"

			KEY_4: # IV도 / iv도
				current_chord_root = (current_root_note + 5) % 12
				current_chord_type = "Maj7" if current_scale_mode == ScaleMode.MAJOR else "m7"

			KEY_5:
				current_chord_root = (current_root_note + 7) % 12
				# Shift를 누르고 5를 누르면 '강력한 V7'로, 그냥 누르면 '서늘한 vm7'로!
				if Input.is_key_pressed(KEY_SHIFT) or current_scale_mode == ScaleMode.MAJOR:
					current_chord_type = "Dom7"
				else:
					current_chord_type = "m7"

			KEY_6: # vi도 / bVI도
				if current_scale_mode == ScaleMode.MAJOR:
					current_chord_root = (current_root_note + 9) % 12
					current_chord_type = "m7"
				else:
					current_chord_root = (current_root_note + 8) % 12 # b6 위치
					current_chord_type = "Maj7"

			KEY_7: # vii도 / bVII도
				if current_scale_mode == ScaleMode.MAJOR:
					current_chord_root = (current_root_note + 11) % 12
					current_chord_type = "m7b5"
				else:
					current_chord_root = (current_root_note + 10) % 12 # b7 위치
					current_chord_type = "Dom7" # bVII7 (Backdoor Dominant 느낌)

func toggle_settings():
	if settings_ui_ref:
		settings_ui_ref.visible = !settings_ui_ref.visible

# --- 음악 논리 함수 ---
func get_note_tier(midi_note: int) -> int:
	var relative_to_chord = (midi_note - current_chord_root) % 12
	if relative_to_chord < 0: relative_to_chord += 12
	
	if relative_to_chord == 0: return 1
	if relative_to_chord in CHORD_TYPES[current_chord_type]: return 2
	
	# 수정: 현재 모드(Major/Minor)에 따른 스케일 판별
	if is_note_in_scale(midi_note): return 3
	
	return 4

func get_movable_do_name(absolute_midi_note: int) -> String:
	var relative_note = (absolute_midi_note - current_root_note) % 12
	if relative_note < 0: relative_note += 12
	match current_notation:
		NotationMode.CDE: return CDE_NAMES[relative_note]
		NotationMode.DOREMI: return DOREMI_NAMES[relative_note]
		_: return "%s (%s)" % [CDE_NAMES[relative_note], DOREMI_NAMES[relative_note]]

# 통합된 스케일 판별 함수
func is_note_in_scale(midi_note: int) -> bool:
	var relative_note = (midi_note - current_root_note) % 12
	if relative_note < 0: relative_note += 12
	
	if current_scale_mode == ScaleMode.MAJOR:
		return relative_note in MAJOR_SCALE_INTERVALS
	else:
		return relative_note in MINOR_SCALE_INTERVALS
