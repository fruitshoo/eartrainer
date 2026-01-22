# progression_manager.gd 수정

extends Node

signal slot_selected(index: int)
signal data_changed(index: int, data: Dictionary) # 데이터 변경 신호 추가

var selected_slot_index: int = 0:
	set(value):
		selected_slot_index = value
		slot_selected.emit(value)

var progression_data = [null, null, null, null]

# 지판에서 데이터를 보내줄 때 실행할 함수
func update_current_slot(midi_note: int, string_num: int, is_shift: bool, is_alt: bool):
	if selected_slot_index < 0: return

	# 1. 기본 타입 계산
	var final_type = MusicTheory.get_smart_type_from_map(
		midi_note,
		GameManager.current_root_note,
		GameManager.current_scale_mode
	)
	
	# 2. 보조키에 따른 변환 (Shift가 Alt보다 우선순위를 갖게 설정)
	if is_shift:
		# [수정] Shift = 항상 세컨더리 도미넌트 (Dom7) - 간단하고 직관적
		final_type = "Dom7"
	elif is_alt:
		final_type = MusicTheory.toggle_maj_min(final_type)

	var new_data = {
		"root": midi_note,
		"type": final_type,
		"string": string_num
	}
	
	progression_data[selected_slot_index] = new_data
	data_changed.emit(selected_slot_index, new_data)
	GameManager.current_chord_type = final_type
