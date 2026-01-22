# progression_manager.gd
# 코드 진행 슬롯 관리 싱글톤
extends Node

# ============================================================
# SIGNALS
# ============================================================
signal slot_selected(index: int)
signal slot_updated(index: int, data: Dictionary)
signal selection_cleared

# ============================================================
# CONSTANTS
# ============================================================
const SLOT_COUNT := 4

# ============================================================
# STATE VARIABLES
# ============================================================
var selected_index: int = -1:
	set(value):
		# [핵심 수정] 하한선을 0이 아니라 -1로 변경합니다.
		selected_index = clampi(value, -1, SLOT_COUNT - 1)
		
		# UI에 선택 상태를 알립니다.
		slot_selected.emit(selected_index)
		
		# 만약 선택이 해제(-1)되었다면 추가 신호를 보냅니다.
		if selected_index == -1:
			selection_cleared.emit()

var slots: Array = [null, null, null, null]

# ============================================================
# PUBLIC API
# ============================================================

## 타일 클릭 시 현재 슬롯에 코드 데이터 저장
func set_slot_from_tile(midi_note: int, string_index: int, is_shift: bool, is_alt: bool) -> void:
	if selected_index < 0:
		return
	
	# 1. 다이어토닉 타입 자동 추론 (기존 로직)
	var chord_type := MusicTheory.get_diatonic_type(
		midi_note,
		GameManager.current_key,
		GameManager.current_mode
	)
	
	# 2. 보조키 수정자 적용 (기존 로직)
	if is_shift:
		chord_type = "Dom7"
	elif is_alt:
		chord_type = MusicTheory.toggle_quality(chord_type)
	
	# 3. 슬롯 데이터 저장 (기존 로직)
	var slot_data := {"root": midi_note, "type": chord_type, "string": string_index}
	slots[selected_index] = slot_data
	slot_updated.emit(selected_index, slot_data)
	
	# 4. 현재 코드 상태 동기화 (기존 로직)
	GameManager.current_chord_type = chord_type

	# ==========================================
	# 🌟 [여기가 핵심 추가 포인트!]
	# ==========================================
	# 입력을 마쳤으니 선택된 인덱스를 초기화(-1)합니다.
	# 이렇게 하면 다음 타일을 클릭해도 첫 번째 줄의 'if selected_index < 0'에서 걸러져서
	# 코드가 변하지 않고 '멜로디 연습'만 가능해집니다!
	selected_index = -1
	
	# UI 버튼의 하이라이트도 꺼달라고 신호를 보냅니다.
	selection_cleared.emit()
	# ==========================================

## 특정 슬롯의 데이터 반환
func get_slot(index: int) -> Variant:
	if index >= 0 and index < SLOT_COUNT:
		return slots[index]
	return null

## 모든 슬롯 초기화
func clear_all() -> void:
	slots = [null, null, null, null]
	selected_index = 0
