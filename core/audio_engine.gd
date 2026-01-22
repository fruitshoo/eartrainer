extends Node

# 준비물: res://assets/audio/ 폴더에 'E2.wav' (6번줄 개방현 소리) 하나를 넣어주세요.
var base_sample = preload("res://assets/audio/E2.wav")

func _ready() -> void:
	EventBus.tile_clicked.connect(_on_tile_clicked)

func _on_tile_clicked(midi_note: int, _string_index: int, _modifiers: Dictionary) -> void:
	play_note(midi_note)

func play_note(midi_note: int) -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	player.stream = base_sample
	
	# MIDI 번호 차이를 이용해 피치 계산 (E2 = 40)
	# 반음당 2^(1/12) 배의 피치 변화
	var pitch_relative = midi_note - 40
	player.pitch_scale = pow(2.0, pitch_relative / 12.0)
	
	player.play()
	
	# 재생이 끝나면 노드 자동 삭제
	player.finished.connect(player.queue_free)