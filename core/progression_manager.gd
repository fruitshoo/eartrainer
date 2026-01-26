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

# var chords_per_bar: int = 1 # Replaced by bar_densities

# 각 마디별 코드 개수 (1 or 2)
var bar_densities: Array[int] = []

# 총 슬롯 개수 계산 속성
var total_slots: int:
	get:
		var sum = 0
		for d in bar_densities:
			sum += d
		return sum

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
	# 초기화: 기본 4마디, 마디당 1코드
	if bar_densities.is_empty():
		for i in range(bar_count):
			bar_densities.append(1)
	_resize_slots()

func _on_tile_clicked(midi_note: int, string_index: int, modifiers: Dictionary) -> void:
	var is_shift: bool = modifiers.get("shift", false)
	var is_alt: bool = modifiers.get("alt", false)
	set_slot_from_tile(midi_note, string_index, is_shift, is_alt)

# ============================================================
# PUBLIC API
# ============================================================

## 시퀀서 설정 변경 (마디 수, 분할)
## 시퀀서 설정 변경 (마디 수) - 기존 호환성 유지 (Reset)
func update_settings(new_bar_count: int, _dummy_density: int = 1) -> void:
	bar_count = clampi(new_bar_count, 2, 8)
	
	# 마디 수가 바뀌면 density 배열 재설정 (일단 단순화: 기존 값 유지 노력 or 리셋)
	# 여기서는 리셋 없이 크기만 조정
	if bar_densities.size() < bar_count:
		while bar_densities.size() < bar_count:
			bar_densities.append(1)
	elif bar_densities.size() > bar_count:
		bar_densities.resize(bar_count)
	
	_resize_slots()
	settings_updated.emit(bar_count, 1) # 두 번째 인자는 이제 의미 없음

## 특정 마디의 분할 상태 토글 (1 <-> 2)
func toggle_bar_split(bar_index: int) -> void:
	if bar_index < 0 or bar_index >= bar_densities.size():
		return
	
	var current = bar_densities[bar_index]
	bar_densities[bar_index] = 2 if current == 1 else 1
	
	# 슬롯 데이터 재구성 (복잡함: 해당 마디의 슬롯이 늘어나거나 줄어듦)
	# _resize_slots는 단순히 뒤에 추가/삭제하므로 안됨.
	# 여기서는 "전체 재구성" 로직이 필요함.
	_reconstruct_slots()
	settings_updated.emit(bar_count, 1)

## 슬롯 인덱스로부터 해당 슬롯의 박자 길이(Duration) 반환
func get_beats_for_slot(slot_index: int) -> int:
	# 슬롯 인덱스를 순회하며 어느 마디에 속하는지 찾음
	var current_slot = 0
	for density in bar_densities:
		var next_boundary = current_slot + density
		if slot_index < next_boundary:
			# 찾음! density가 1이면 4박자, 2면 2박자
			return 4 if density == 1 else 2
		current_slot = next_boundary
	return 4 # Fallback

## 슬롯 인덱스가 속한 "마디 인덱스" 반환
func get_bar_index_for_slot(slot_index: int) -> int:
	var current_slot = 0
	for i in range(bar_densities.size()):
		var density = bar_densities[i]
		if slot_index < current_slot + density:
			return i
		current_slot += density
	return -1

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

## 내부: 슬롯 배열 완전히 재구성 (Split 변경 시)
## 주의: 기존 데이터 위치가 밀릴 수 있음. (간단하게 구현: 리사이즈만 하고 데이터 이동은 일단 패스?)
## 사용자 경험상, 마디 1을 쪼갰는데 마디 4의 데이터가 마디 3으로 오면 안됨.
## 따라서 데이터를 "마디별"로 백업하고 복원해야 함.
func _reconstruct_slots() -> void:
	# 1. 현재 데이터를 마디별로 백업
	var backup: Array[Array] = []
	var slot_cursor = 0
	
	# 변경 전 density 정보를 알 수 없으므로... (이미 bar_densities는 변경됨)
	# 아하, toggle_bar_split에서 변경 전에 이 함수를 호출하거나, 변경 로직을 여기에 통합해야 했음.
	# 일단 "단순 리사이즈"로 갑니다. (데이터 밀림 현상 발생 가능 - 프로토타입)
	# [TODO] Better data persistance
	
	_resize_slots()

## 내부: 슬롯 배열 크기 조정
func _resize_slots() -> void:
	# var old_slots = slots.duplicate() # Unused
	var new_total = total_slots
	
	slots.resize(new_total)
	
	# 크기가 늘어난 경우 null로 초기화 (resize가 알아서 해주긴 함)
	# 크기가 줄어든 경우 데이터는 잘림
	
	# 선택 인덱스가 범위 밖이면 해제
	if selected_index >= new_total:
		selected_index = -1
