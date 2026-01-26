# progression_manager.gd
# 코드 진행 슬롯 관리 싱글톤
extends Node

# ============================================================
# ============================================================
# SIGNALS
# ============================================================
signal slot_selected(index: int)
signal slot_updated(index: int, data: Dictionary)
signal selection_cleared
signal settings_updated(bar_count: int, chords_per_bar: int) # [New] 설정 변경 알림

# ============================================================
# STATE VARIABLES
# ============================================================
var bar_count: int = 4
var chords_per_bar: int = 1

# 총 슬롯 개수 계산 속성
var total_slots: int:
	get: return bar_count * chords_per_bar

var selected_index: int = -1:
	set(value):
		selected_index = clampi(value, -1, total_slots - 1)
		slot_selected.emit(selected_index)
		if selected_index == -1:
			selection_cleared.emit()

var slots: Array = []

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	EventBus.tile_clicked.connect(_on_tile_clicked)
	_resize_slots() # 초기화

func _on_tile_clicked(midi_note: int, string_index: int, modifiers: Dictionary) -> void:
	var is_shift: bool = modifiers.get("shift", false)
	var is_alt: bool = modifiers.get("alt", false)
	set_slot_from_tile(midi_note, string_index, is_shift, is_alt)

# ============================================================
# PUBLIC API
# ============================================================

## 시퀀서 설정 변경 (마디 수, 분할)
func update_settings(new_bar_count: int, new_chords_per_bar: int) -> void:
	bar_count = clampi(new_bar_count, 2, 8)
	chords_per_bar = clampi(new_chords_per_bar, 1, 2) # 1=한마디1코드, 2=한마디2코드
	
	_resize_slots()
	settings_updated.emit(bar_count, chords_per_bar)

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
		chord_type = "7"
	elif is_alt:
		chord_type = MusicTheory.toggle_quality(chord_type)
	
	# 3. 슬롯 데이터 저장
	var slot_data := {"root": midi_note, "type": chord_type, "string": string_index}
	
	# 안전장치: 인덱스 범위 확인
	if selected_index < slots.size():
		slots[selected_index] = slot_data
		slot_updated.emit(selected_index, slot_data)
	
	# 4. 입력 완료 → 선택 해제
	selected_index = -1
	selection_cleared.emit()

## 특정 슬롯의 데이터 반환
func get_slot(index: int) -> Variant:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

## 모든 슬롯 초기화
func clear_all() -> void:
	for i in range(slots.size()):
		slots[i] = null
		slot_updated.emit(i, {}) # UI 갱신용 빈 데이터
	selected_index = -1

## 특정 슬롯 초기화
func clear_slot(index: int) -> void:
	if index >= 0 and index < slots.size():
		slots[index] = null
		slot_updated.emit(index, {})
		if selected_index == index:
			selected_index = -1
			selection_cleared.emit()

## 내부: 슬롯 배열 크기 조정 (기존 데이터 보존 노력)
func _resize_slots() -> void:
	# var old_slots = slots.duplicate() # Unused
	var new_total = total_slots
	
	slots.resize(new_total)
	
	# 크기가 늘어난 경우 null로 초기화 (resize가 알아서 해주긴 함)
	# 크기가 줄어든 경우 데이터는 잘림
	
	# 선택 인덱스가 범위 밖이면 해제
	if selected_index >= new_total:
		selected_index = -1
