# sequencer.gd
extends Node

signal beat_started(slot_index: int) # 새로운 마디가 시작될 때 보내는 신호

@export var bpm: int = 80
var current_step: int = 0
var is_playing: bool = false

@onready var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.timeout.connect(_on_bar_timeout)

func toggle_play():
	is_playing = !is_playing
	if is_playing:
		current_step = 0
		_start_bar()
	else:
		timer.stop()

func _start_bar():
	# 4박자(1마디)의 길이를 초 단위로 계산합니다.
	# 공식: (60 / BPM) * 4
	var bar_duration = (60.0 / bpm) * 4.0
	
	# 현재 슬롯의 데이터를 게임에 적용 (발광/소리 등)
	_apply_current_step()
	
	beat_started.emit(current_step)
	
	timer.start(bar_duration)

func _on_bar_timeout():
	# 다음 슬롯으로 이동 (4칸 루프)
	current_step = (current_step + 1) % 4
	_start_bar()

func _apply_current_step():
	var data = ProgressionManager.progression_data[current_step]
	if data == null: return # 데이터가 없는 빈 슬롯이면 통과
	
	# 1. GameManager의 상태를 업데이트 (지판 조명 변경)
	GameManager.current_chord_root = data.root
	GameManager.current_chord_type = data.type
	
	# 2. [추가] 스마트 스트럼 실행
	play_strum(data.root, data.type)

# 촤라랑~ 소리를 내는 함수
# sequencer.gd 의 play_strum 함수 수정

func play_strum(root_note: int, type: String):
	var data = ProgressionManager.progression_data[current_step]
	if data == null: return
	
	var root_string = data.string
	var root_fret = MusicTheory.get_fret_pos(data.root, root_string)
	
	print("\n--- [진단 시작] ---")
	print("1. 저장된 줄 번호(인덱스): ", root_string)
	print("2. 계산된 프렛 위치: ", root_fret)

	# 6번 줄은 이제 인덱스 0입니다!
	var shape_key = "6th_String_Root" if root_string == 0 else "5th_String_Root"
	var offsets = MusicTheory.SHAPE_OFFSETS.get(shape_key).get(type, [[0, 0]])

	for offset in offsets:
		var target_s = root_string + offset[0]
		var target_f = root_fret + offset[1]
		
		var tile = GameManager.get_tile(target_s, target_f)
		if tile:
			print("성공: [", target_s, "줄, ", target_f, "프렛] 타일 연주")
			AudioEngine.play_note(tile.midi_note)
			tile.apply_visual_tier(Color(2.0, 2.0, 2.0), 3.0)
			restore_tile_visual(tile)
		else:
			print("실패: [", target_s, "줄, ", target_f, "프렛] 위치에 타일이 없음!")
		
		await get_tree().create_timer(0.05).timeout

# 번쩍인 타일을 원래대로 돌려놓는 보조 함수
func restore_tile_visual(tile):
	await get_tree().create_timer(0.1).timeout
	if tile:
		tile.update_appearance() # 타일이 이미 가진 함수로 원래 색 복구!
