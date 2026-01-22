# progression_manager.gd
# 코드 진행 슬롯 관리 싱글톤
extends Node

# ============================================================
# SIGNALS
# ============================================================
signal slot_selected(index: int)
signal slot_updated(index: int, data: Dictionary)

# ============================================================
# CONSTANTS
# ============================================================
const SLOT_COUNT := 4

# ============================================================
# STATE VARIABLES
# ============================================================
var selected_index: int = 0:
	set(value):
		selected_index = clampi(value, 0, SLOT_COUNT - 1)
		slot_selected.emit(selected_index)

var slots: Array = [null, null, null, null]

# ============================================================
# PUBLIC API
# ============================================================

## 타일 클릭 시 현재 슬롯에 코드 데이터 저장
func set_slot_from_tile(midi_note: int, string_index: int, is_shift: bool, is_alt: bool) -> void:
	if selected_index < 0:
		return
	
	# 1. 다이어토닉 타입 자동 추론
	var chord_type := MusicTheory.get_diatonic_type(
		midi_note,
		GameManager.current_key,
		GameManager.current_mode
	)
	
	# 2. 보조키 수정자 적용
	if is_shift:
		chord_type = "Dom7" # 세컨더리 도미넌트
	elif is_alt:
		chord_type = MusicTheory.toggle_quality(chord_type)
	
	# 3. 슬롯 데이터 저장
	var slot_data := {
		"root": midi_note,
		"type": chord_type,
		"string": string_index
	}
	
	slots[selected_index] = slot_data
	slot_updated.emit(selected_index, slot_data)
	
	# 4. 현재 코드 상태 동기화
	GameManager.current_chord_type = chord_type

## 특정 슬롯의 데이터 반환
func get_slot(index: int) -> Variant:
	if index >= 0 and index < SLOT_COUNT:
		return slots[index]
	return null

## 모든 슬롯 초기화
func clear_all() -> void:
	slots = [null, null, null, null]
	selected_index = 0
