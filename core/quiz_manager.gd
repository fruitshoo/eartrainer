extends Node

signal quiz_started(note: int)
signal quiz_answered(is_correct: bool)

var current_target_note: int = -1

# 1. 문제 출제
func start_new_quiz():
	# 6줄 12프렛 범위 내에서 랜덤한 MIDI 번호 추출
	# (0프렛 ~ 12프렛, 각 줄의 시작음 기준)
	var random_string = randi() % 6
	var random_fret = randi() % 13
	
	# FretboardManager의 string_root_notes를 참조하여 MIDI 값 계산
	# (GameManager 등에 저장된 root_notes를 사용하세요)
	var root_notes = [40, 45, 50, 55, 59, 64] # 낮은 E부터
	current_target_note = root_notes[random_string] + random_fret
	
	# 소리 들려주기
	AudioEngine.play_note(current_target_note)
	quiz_started.emit(current_target_note)
	print("문제 출제됨: ", current_target_note)

# 2. 정답 체크 (타일 클릭 시 호출)
func check_answer(clicked_note: int):
	if current_target_note == -1: return
	
	# 옥타브를 무시하고 계이름만 맞출지, 정확한 위치를 맞출지 선택 가능
	# 여기서는 '정확한 위치'를 맞추는 것으로 설정
	var is_correct = (clicked_note == current_target_note)
	
	if is_correct:
		print("정답입니다!")
		# 성공 사운드 재생 로직 추가 가능
	else:
		print("틀렸습니다. 다시 들어보세요.")
		AudioEngine.play_note(current_target_note) # 다시 들려줌
	
	quiz_answered.emit(is_correct)
	
	if is_correct:
		# 잠시 후 다음 문제 출제
		await get_tree().create_timer(1.5).timeout
		start_new_quiz()