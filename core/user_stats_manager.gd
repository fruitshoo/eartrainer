# user_stats_manager.gd
# 경험치, 레벨, 스트릭 관리자
extends Node

signal stats_updated

const SAVE_PATH = "user://user_stats.json"
const XP_PER_CORRECT = 10
const LEVEL_UP_BASE = 100

var total_xp: int = 0
var level: int = 1
var current_streak: int = 0
var max_streak: int = 0
var correct_count: int = 0

func _ready() -> void:
	# 1. 초기화 및 로드
	load_stats()
	
	# 2. 퀴즈 결과 연결
	# QuizManager가 Autoload이므로 바로 접근 가능
	QuizManager.quiz_answered.connect(_on_quiz_answered)
	
	GameLogger.info("[UserStatsManager] Initialized. Level: %d, XP: %d" % [level, total_xp])

func _on_quiz_answered(result: Dictionary) -> void:
	if result.get("correct", false):
		_add_xp(XP_PER_CORRECT)
		current_streak += 1
		max_streak = max(max_streak, current_streak)
		correct_count += 1
	else:
		current_streak = 0
		
	stats_updated.emit()
	save_stats()

func _add_xp(amount: int) -> void:
	total_xp += amount
	_check_level_up()

func _check_level_up() -> void:
	var next_level_xp = level * LEVEL_UP_BASE
	if total_xp >= next_level_xp:
		level += 1
		GameLogger.info("[UserStatsManager] Level Up! New Level: %d" % level)
		# 레벨업 연출을 위한 시그널이나 효과는 나중에 추가
		_check_level_up() # 다중 레벨업 처리

# ============================================================
# DATA PERSISTENCE
# ============================================================
func save_stats() -> void:
	var data = {
		"total_xp": total_xp,
		"level": level,
		"max_streak": max_streak,
		"total_correct": correct_count
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_stats() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var data = JSON.parse_string(json_string)
		if data is Dictionary:
			total_xp = data.get("total_xp", 0)
			level = data.get("level", 1)
			max_streak = data.get("max_streak", 0)
			correct_count = data.get("total_correct", 0)
		file.close()
