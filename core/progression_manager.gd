# progression_manager.gd
# 코드 진행 슬롯 관리 싱글톤
extends Node

const PROGRESSION_MANAGER_IO = preload("res://core/progression_manager_io.gd")
const PROGRESSION_MANAGER_SLOTS = preload("res://core/progression_manager_slots.gd")
const PROGRESSION_MANAGER_MELODY = preload("res://core/progression_manager_melody.gd")
const PROGRESSION_MANAGER_CLIPBOARD = preload("res://core/progression_manager_clipboard.gd")

# ============================================================
# ============================================================
# SIGNALS
# ============================================================
signal slot_selected(index: int)
signal slot_updated(index: int, data: Dictionary)
signal selection_cleared
signal loop_range_changed(start: int, end: int) # [New] 루프 구간 변경 알림
signal settings_updated(bar_count: int, chords_per_bar: int) # [New] 설정 변경 알림
signal melody_updated(bar_idx: int) # [New] 멜로디 변경 알림
signal section_labels_changed

const SESSION_SAVE_DEBOUNCE_SEC := 0.12

# ============================================================
# STATE VARIABLES
# ============================================================
var bar_count: int = 4
var beats_per_bar: int = 4 # [New] 4/4 or 3/4
var playback_mode: MusicTheory.ChordPlaybackMode = MusicTheory.ChordPlaybackMode.ONCE


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
var section_labels: Dictionary = {}
var bar_clipboard: Dictionary = {}

# [New] Melody Data: Key = Bar Index, Value = Dictionary { "beat_sub": NoteData }
# beat: 0..3, sub: 0..1 (8th notes). Key format: "0_0", "0_1", ... "3_1"
var melody_events: Dictionary = {}
var _save_timer: Timer
var _save_pending: bool = false
var _io_helper: ProgressionManagerIO
var _slot_helper: ProgressionManagerSlots
var _melody_helper: ProgressionManagerMelody
var _clipboard_helper: ProgressionManagerClipboard

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_io_helper = PROGRESSION_MANAGER_IO.new(self)
	_slot_helper = PROGRESSION_MANAGER_SLOTS.new(self)
	_melody_helper = PROGRESSION_MANAGER_MELODY.new(self)
	_clipboard_helper = PROGRESSION_MANAGER_CLIPBOARD.new(self, _slot_helper)
	playback_mode = MusicTheory.ChordPlaybackMode.ONCE
	EventBus.tile_clicked.connect(_on_tile_clicked)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SESSION_SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(_flush_session_save)
	add_child(_save_timer)
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
		var target_preset = _io_helper.load_preset_data(default_name)
				
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
	slots[0] = {"root": note_ii, "type": "m7", "string": 1}
	
	# Slot 1: V (5도)
	var note_v = (key + 7) % 12
	slots[1] = {"root": note_v, "type": "7", "string": 1}
	
	# Slot 2: I (1도)
	slots[2] = {"root": key, "type": "M7", "string": 1}
	
	# Slot 3: I (1도)
	slots[3] = {"root": key, "type": "M7", "string": 1}
	
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
	_slot_helper.update_settings(new_bar_count)

## [New] 박자 설정 (4 or 3)
func set_time_signature(beats: int) -> void:
	_slot_helper.set_time_signature(beats)


## 특정 마디의 분할 상태 토글 (1 <-> 2)
func toggle_bar_split(bar_index: int) -> void:
	_slot_helper.toggle_bar_split(bar_index)

## [New] UI 강제 갱신 (SongManager 등 외부에서 데이터 로드 시 사용)
func force_refresh_ui() -> void:
	_slot_helper.force_refresh_ui()

func get_section_label(bar_index: int) -> String:
	return _slot_helper.get_section_label(bar_index)

func set_section_label(bar_index: int, label: String) -> void:
	_slot_helper.set_section_label(bar_index, label)

func clear_section_label(bar_index: int) -> void:
	_slot_helper.clear_section_label(bar_index)

func copy_bar(bar_index: int) -> void:
	_clipboard_helper.copy_bar(bar_index)

func copy_bar_range(start_bar: int, end_bar: int) -> void:
	_clipboard_helper.copy_bar_range(start_bar, end_bar)

func paste_bar(bar_index: int) -> void:
	_clipboard_helper.paste_bar(bar_index)

func paste_bar_range(start_bar: int, end_bar: int) -> void:
	_clipboard_helper.paste_bar_range(start_bar, end_bar)

func has_bar_clipboard() -> bool:
	return _clipboard_helper.has_bar_clipboard()

func get_loop_bar_range() -> Vector2i:
	return _slot_helper.get_loop_bar_range()

func get_bar_clipboard_length() -> int:
	return _clipboard_helper.get_bar_clipboard_length()

func get_bar_clipboard_source_range() -> Vector2i:
	return _clipboard_helper.get_bar_clipboard_source_range()

func get_bar_clipboard_next_paste_bar() -> int:
	return _clipboard_helper.get_bar_clipboard_next_paste_bar()

## 슬롯 인덱스로부터 해당 슬롯의 박자 길이(Duration) 반환
func get_beats_for_slot(slot_index: int) -> int:
	return _slot_helper.get_beats_for_slot(slot_index)

## 슬롯 인덱스가 속한 "마디 인덱스" 반환
func get_bar_index_for_slot(slot_index: int) -> int:
	return _slot_helper.get_bar_index_for_slot(slot_index)

## 마디 인덱스로부터 해당 마디의 첫 번째 슬롯 인덱스 반환
func get_slot_index_for_bar(bar_index: int) -> int:
	return _slot_helper.get_slot_index_for_bar(bar_index)

## 타일 클릭 시 현재 슬롯에 코드 데이터 저장
func set_slot_from_tile(midi_note: int, string_index: int, is_shift: bool, is_alt: bool) -> void:
	_slot_helper.set_slot_from_tile(midi_note, string_index, is_shift, is_alt)

func set_slot_data(index: int, slot_data: Dictionary, clear_selection: bool = false) -> void:
	_slot_helper.set_slot_data(index, slot_data, clear_selection)

func set_selected_slot_type(chord_type: String) -> void:
	_slot_helper.set_selected_slot_type(chord_type)

## 루프 구간 설정
func set_loop_range(start: int, end: int) -> void:
	_slot_helper.set_loop_range(start, end)

## 루프 구간 해제
func clear_loop_range() -> void:
	_slot_helper.clear_loop_range()

## 특정 슬롯의 데이터 반환
func get_slot(index: int) -> Variant:
	return _slot_helper.get_slot(index)

## [New] 특정 슬롯의 데이터를 Dictionary로 반환 (Null 안전)
func get_chord_data(index: int) -> Dictionary:
	return _slot_helper.get_chord_data(index)

## 모든 슬롯 초기화
func clear_all() -> void:
	_slot_helper.clear_all()

## 특정 슬롯 초기화
func clear_slot(index: int) -> void:
	_slot_helper.clear_slot(index)

## 내부: 슬롯 배열 완전히 재구성 (Split 변경 시)
## 주의: 기존 데이터 위치가 밀릴 수 있음. (간단하게 구현: 리사이즈만 하고 데이터 이동은 일단 패스?)
## 사용자 경험상, 마디 1을 쪼갰는데 마디 4의 데이터가 마디 3으로 오면 안됨.
## 따라서 데이터를 "마디별"로 백업하고 복원해야 함.
func _reconstruct_slots() -> void:
	_slot_helper.reconstruct_slots()

## 내부: 슬롯 배열 크기 조정
func _resize_slots() -> void:
	_slot_helper.resize_slots()

# ============================================================
# MELODY API
# ============================================================

## [New] 멜로디 노트 설정
func set_melody_note(bar_idx: int, beat: int, sub: int, note_data: Dictionary) -> void:
	_melody_helper.set_melody_note(bar_idx, beat, sub, note_data)

## [New] 멜로디 노트 삭제
func clear_melody_note(bar_idx: int, beat: int, sub: int) -> void:
	_melody_helper.clear_melody_note(bar_idx, beat, sub)

## [New] 특정 마디의 멜로디 데이터 반환
func get_melody_events(bar_idx: int) -> Dictionary:
	return _melody_helper.get_melody_events(bar_idx)

## [New] 멜로디 전체 교체
func replace_all_melody_events(new_events: Dictionary) -> void:
	_melody_helper.replace_all_melody_events(new_events)

## [New] 멜로디 전체 초기화
func clear_all_melody() -> void:
	_melody_helper.clear_all_melody()

# ============================================================
# PERSISTENCE (Auto-save)
# ============================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_session(true)

## 세션 자동 저장
func save_session(immediate: bool = false) -> void:
	_save_pending = true
	if immediate:
		_flush_session_save()
		return
	if _save_timer:
		_save_timer.start()

func _flush_session_save() -> void:
	_io_helper.flush_session_save()

## 세션 자동 불러오기
func load_session() -> void:
	_io_helper.load_session()

func serialize() -> Dictionary:
	return _io_helper.serialize()

func deserialize(data: Dictionary) -> void:
	_io_helper.deserialize(data)

# ============================================================
# PRESET LIBRARY (Saved Progressions)
# ============================================================

func get_preset_list() -> Array[Dictionary]:
	return _io_helper.get_preset_list()

func save_preset(name: String) -> void:
	_io_helper.save_preset(name)

func load_preset(name: String) -> void:
	_io_helper.load_preset(name)

func delete_preset(name: String) -> void:
	_io_helper.delete_preset(name)

func reorder_presets(from_idx: int, to_idx: int) -> void:
	_io_helper.reorder_presets(from_idx, to_idx)
