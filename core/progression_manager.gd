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
	
	# [Refactor] Deterministic Startup Logic
	if not GameManager.is_settings_loaded:
		await GameManager.settings_loaded
		
	load_startup_state()

func load_startup_state() -> void:
	# 1. Try to load default preset if set
	var default_name = GameManager.default_preset_name
	if not default_name.is_empty():
		# Check if preset exists
		var presets = _load_presets_safe()
		var target_preset = {}
		for p in presets:
			if p["name"] == default_name:
				target_preset = p
				break
				
		if not target_preset.is_empty():
			load_preset(default_name)
			print("[ProgressionManager] Loaded default preset: ", default_name)
			
			# Force UI Refresh
			await get_tree().process_frame
			settings_updated.emit(bar_count, 1)
			return

	# 2. Fallback to Default Progression (2-5-1)
	load_default_progression()
	
func load_default_progression() -> void:
	print("[ProgressionManager] Loading fallback default progression (2-5-1)")
	
	# Reset to standard 4 bars
	bar_count = 4
	bar_densities = [1, 1, 1, 1]
	_resize_slots()
	
	for i in range(slots.size()):
		slots[i] = null
		
	# II - V - I - I (Jazz Standard) in Current Key
	# Current Key is loaded from GameManager (which is loaded from settings)
	var key = GameManager.current_key
	
	# Slot 0: ii (2도)
	var note_ii = (key + 2) % 12
	slots[0] = {"root": note_ii, "type": "m7", "string": 0}
	
	# Slot 1: V (5도)
	var note_v = (key + 7) % 12
	slots[1] = {"root": note_v, "type": "7", "string": 0}
	
	# Slot 2: I (1도)
	slots[2] = {"root": key, "type": "M7", "string": 0}
	
	# Slot 3: I (1도)
	slots[3] = {"root": key, "type": "M7", "string": 0}
	
	# Update UI
	# Yield a frame to ensure UI is ready
	await get_tree().process_frame
	settings_updated.emit(bar_count, 1)
	for i in range(slots.size()):
		slot_updated.emit(i, slots[i])

# ... (omitted) ...

# ... (omitted) ...


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
		
	# [BugFix] 루프 구간이 설정된 상태(여러 슬롯 선택)라면 코드 입력을 막는다.
	# 단, 단일 슬롯 선택(Start==End)인 경우는 허용할 수도 있지만,
	# UI 로직상 Shift+Click으로 구간을 잡으면 Start != End가 됨.
	if loop_start_index != -1 and loop_end_index != -1:
		if loop_start_index != loop_end_index:
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
		# [Debug] Log modification
		# if selected_index == 0:
		# 	var msg = "Slot[0] MODIFIED by Tile! (%d)" % midi_note
		# 	EventBus.debug_log.emit(msg)
		# 	print(msg)
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
	
	# [Refinement] 루프 구간이 생성되면 기존 단일 슬롯 선택은 해제한다.
	# (시각적으로 루프 구간(흰색)만 남기고 노란색 슬롯을 없앰)
	if selected_index != -1:
		selected_index = -1
		selection_cleared.emit()
		
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
	var success = _save_json(SAVE_PATH_SESSION, data)
	
	# [Debug] Wait a bit for HUD to be ready, then load
	await get_tree().create_timer(0.5).timeout
	load_session()
	
	# [Fix] Force UI Refresh after load to prevent display glitch
	# Increased delay to 2.0s (known stable timing) to ensure UI is fully initialized
	await get_tree().create_timer(2.0).timeout
	settings_updated.emit(bar_count, 1)
	
	# [Debug] Verify persistence
	var real_path = ProjectSettings.globalize_path(SAVE_PATH_SESSION)
	if success:
		# if slots.size() > 0 and slots[0] != null:
		# 	var root = slots[0].get("root", "?")
		# 	EventBus.debug_log.emit("Saved to: %s\nSlot[0]: %s" % [real_path, root])
		# else:
		# 	EventBus.debug_log.emit("Saved to: %s\nSlot[0]: Empty" % real_path)
		print("Full Save Path: ", real_path)
	else:
		# EventBus.debug_log.emit("Save FAILED! Path: %s" % real_path)
		print("Save FAILED! Path: %s" % real_path)

## 세션 자동 불러오기
func load_session() -> void:
	if not FileAccess.file_exists(SAVE_PATH_SESSION):
		# EventBus.debug_log.emit("No session file.")
		print("No session file.")
		return
		
	var data = _load_json(SAVE_PATH_SESSION)
	if data:
		_deserialize_data(data)
		# if slots.size() > 0 and slots[0] != null:
		# 	var root = slots[0].get("root", "?")
		# 	EventBus.debug_log.emit("Session Loaded. Slot[0] Root: %s" % root)
		# else:
		# 	EventBus.debug_log.emit("Session Loaded. Slot[0]: Empty")
		# The original code had `print("Full Save Path: ", real_path)` here, but `real_path` is not defined in this scope.
		# Assuming it was meant to be removed or defined locally if needed.
		# For now, I'm keeping the user's provided snippet which removes it.

func _deserialize_data(data: Dictionary) -> void:
	bar_count = data.get("bar_count", 4)
	# EventBus.debug_log.emit("Deserializing: Bars=%d" % bar_count)
	
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
	
	# [Fix] Clear all slots to prevent stale data from previous state
	for k in range(slots.size()):
		slots[k] = null
	
	var saved_slots = data.get("slots", [])
	for i in range(min(slots.size(), saved_slots.size())):
		var s = saved_slots[i]
		if s is Dictionary:
			# [Fix] JSON loads numbers as floats. Convert to int for safety.
			if s.has("root"): s["root"] = int(s["root"])
			if s.has("string"): s["string"] = int(s["string"])
			slots[i] = s.duplicate() # [Safety] Duplicate
		else:
			slots[i] = s # null or primitive
	
	# Loop Range 복원
	loop_start_index = data.get("loop_start", -1)
	loop_end_index = data.get("loop_end", -1)
	
	# UI 리프레시를 위해 시그널 방출
	# [Fix] settings_updated updates existing slots, slot_updated refreshes content.
	settings_updated.emit(bar_count, 1)
	loop_range_changed.emit(loop_start_index, loop_end_index)
	for i in range(slots.size()):
		slot_updated.emit(i, slots[i] if slots[i] else {})

# ============================================================
# PRESET LIBRARY (Saved Progressions)
# ============================================================
# ============================================================
# PRESET LIBRARY (Saved Progressions)
# ============================================================
# ============================================================
# PRESET LIBRARY (Saved Progressions)
# ============================================================
const SAVE_PATH_PRESETS = "user://presets.json"

## 프리셋 목록 반환 (순서 보장됨)
func get_preset_list() -> Array[Dictionary]:
	var presets = _load_presets_safe()
	return presets

## 현재 상태를 프리셋으로 저장
func save_preset(name: String) -> void:
	if name.strip_edges().is_empty():
		return
		
	var presets = _load_presets_safe()
	
	var new_data = {
		"name": name,
		"key": GameManager.current_key,
		"mode": GameManager.current_mode,
		"bar_count": bar_count,
		"bar_densities": bar_densities,
		"slots": slots,
		"melody_tracks": [],
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# 중복 이름 확인: 덮어쓰기
	var found_idx = -1
	for i in range(presets.size()):
		if presets[i]["name"] == name:
			found_idx = i
			break
	
	if found_idx != -1:
		presets[found_idx] = new_data
	else:
		presets.append(new_data)
		
	_save_json(SAVE_PATH_PRESETS, presets)
	print("[ProgressionManager] Preset saved: ", name)

## 프리셋 불러오기
func load_preset(name: String) -> void:
	var presets = _load_presets_safe()
	var target_data = {}
	
	for p in presets:
		if p["name"] == name:
			target_data = p
			break
			
	if target_data.is_empty():
		return
	
	# 1. 키/모드 복원
	if target_data.has("key") and target_data.has("mode"):
		GameManager.current_key = int(target_data["key"])
		GameManager.current_mode = int(target_data["mode"])
		EventBus.game_settings_changed.emit()
	
	# 2. 시퀀서 데이터 복원
	_deserialize_data(target_data)
	save_session()
	print("[ProgressionManager] Preset loaded: ", name)

## 프리셋 삭제
func delete_preset(name: String) -> void:
	var presets = _load_presets_safe()
	var found_idx = -1
	for i in range(presets.size()):
		if presets[i]["name"] == name:
			found_idx = i
			break
			
	if found_idx != -1:
		presets.remove_at(found_idx)
		_save_json(SAVE_PATH_PRESETS, presets)
		print("[ProgressionManager] Preset deleted: ", name)

## 프리셋 순서 변경
func reorder_presets(from_idx: int, to_idx: int) -> void:
	var presets = _load_presets_safe()
	if from_idx < 0 or from_idx >= presets.size() or to_idx < 0 or to_idx >= presets.size():
		return
		
	var item = presets.pop_at(from_idx)
	presets.insert(to_idx, item)
	_save_json(SAVE_PATH_PRESETS, presets)

## 내부: 안전하게 로드하고 마이그레이션 처리
func _load_presets_safe() -> Array[Dictionary]:
	var raw_data = _load_json(SAVE_PATH_PRESETS)
	
	# Case 1: File doesn't exist or empty
	if raw_data == null:
		return []
		
	# Case 2: Dictionary (Old Format) -> Optimize Migration
	if raw_data is Dictionary:
		print("[ProgressionManager] Migrating presets from Dict to Array...")
		var list: Array[Dictionary] = []
		for key in raw_data.keys():
			var item = raw_data[key]
			item["name"] = key # Ensure name exists
			list.append(item)
		
		# Sort by timestamp (Old behavior)
		list.sort_custom(func(a, b): return a.get("timestamp", 0) > b.get("timestamp", 0))
		
		# Save immediately as Array
		_save_json(SAVE_PATH_PRESETS, list)
		return list
		
	# Case 3: Array (New Format)
	if raw_data is Array:
		# Type safety check
		var typed_list: Array[Dictionary] = []
		for item in raw_data:
			if item is Dictionary:
				typed_list.append(item)
		return typed_list
		
	return []

# --- File I/O Helpers ---

func _save_json(path: String, data: Variant) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		return true
	else:
		var err = FileAccess.get_open_error()
		print("[ProgressionManager] Error opening file %s: %d" % [path, err])
		# EventBus.debug_log.emit("File Error: %d" % err)
		return false

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
