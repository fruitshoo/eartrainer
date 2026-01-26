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
signal loop_range_changed(start: int, end: int) # [New] 루프 구간 변경 알림
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

# Loop Range (-1 means no loop)
var loop_start_index: int = -1
var loop_end_index: int = -1

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
	call_deferred("load_session") # [Persistence] Auto-load last session

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
	save_session()

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
	save_session()

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
	
	save_session()

## 루프 구간 설정
func set_loop_range(start: int, end: int) -> void:
	if start < 0 or end < 0 or start > end or end >= total_slots:
		return
		
	loop_start_index = start
	loop_end_index = end
	loop_range_changed.emit(loop_start_index, loop_end_index)
	save_session()

## 루프 구간 해제
func clear_loop_range() -> void:
	loop_start_index = -1
	loop_end_index = -1
	loop_range_changed.emit(-1, -1)
	save_session()

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
	save_session()

## 특정 슬롯 초기화
func clear_slot(index: int) -> void:
	if index >= 0 and index < slots.size():
		slots[index] = null
		slot_updated.emit(index, {})
		if selected_index == index:
			selected_index = -1
			selection_cleared.emit()
	save_session()

## 내부: 슬롯 배열 완전히 재구성 (Split 변경 시)
## 주의: 기존 데이터 위치가 밀릴 수 있음. (간단하게 구현: 리사이즈만 하고 데이터 이동은 일단 패스?)
## 사용자 경험상, 마디 1을 쪼갰는데 마디 4의 데이터가 마디 3으로 오면 안됨.
## 따라서 데이터를 "마디별"로 백업하고 복원해야 함.
func _reconstruct_slots() -> void:
	# 데이터 유지를 위한 임시 저장
	var old_slots = slots.duplicate()
	
	_resize_slots()
	
	# 가능한 만큼 복원 (단순 인덱스 매핑)
	for i in range(min(old_slots.size(), slots.size())):
		slots[i] = old_slots[i]
		slot_updated.emit(i, slots[i] if slots[i] else {})

## 내부: 슬롯 배열 크기 조정
func _resize_slots() -> void:
	var new_total = total_slots
	slots.resize(new_total)
	
	if selected_index >= new_total:
		selected_index = -1
	
	# 루프 범위가 새 크기를 벗어나면 초기화
	if loop_end_index >= new_total:
		clear_loop_range()

# ============================================================
# PERSISTENCE (Auto-save)
# ============================================================
const SAVE_PATH_SESSION = "user://last_session.json"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_session()

## 세션 자동 저장
func save_session() -> void:
	var data = {
		"version": 1,
		"bar_count": bar_count,
		"bar_densities": bar_densities,
		"slots": slots,
		"loop_start": loop_start_index,
		"loop_end": loop_end_index
	}
	_save_json(SAVE_PATH_SESSION, data)
	print("[ProgressionManager] Session saved.")

## 세션 자동 불러오기
func load_session() -> void:
	if not FileAccess.file_exists(SAVE_PATH_SESSION):
		return
		
	var data = _load_json(SAVE_PATH_SESSION)
	if data:
		_deserialize_data(data)
		print("[ProgressionManager] Session loaded.")

func _deserialize_data(data: Dictionary) -> void:
	bar_count = data.get("bar_count", 4)
	
	var saved_densities = data.get("bar_densities", [])
	if saved_densities.size() > 0:
		bar_densities.clear()
		for d in saved_densities:
			bar_densities.append(int(d))
	else:
		# Fallback
		bar_densities.clear()
		for i in range(bar_count):
			bar_densities.append(1)
	
	_resize_slots()
	
	
	var saved_slots = data.get("slots", [])
	for i in range(min(slots.size(), saved_slots.size())):
		slots[i] = saved_slots[i]
	
	# Loop Range 복원
	loop_start_index = data.get("loop_start", -1)
	loop_end_index = data.get("loop_end", -1)
	
	# UI 리프레시를 위해 시그널 방출
	settings_updated.emit(bar_count, 1) # Note: second arg unused now
	loop_range_changed.emit(loop_start_index, loop_end_index)
	for i in range(slots.size()):
		slot_updated.emit(i, slots[i] if slots[i] else {})

# --- File I/O Helpers ---

func _save_json(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(text)
		if error == OK:
			return json.data
	return null
