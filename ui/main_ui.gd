class_name MainUI
extends CanvasLayer

## MainUI: HUD와 SequenceUI만 관리하는 기본 UI 레이어
## SettingsUI, EarTrainerUI는 독립 CanvasLayer로 main.tscn에서 직접 관리

@onready var game_ui_container: Control = %GameUIContainer
@onready var hud: Control = game_ui_container.get_node("HUD")
@onready var sequence_ui: Control = game_ui_container.get_node("SequenceUI")

func _ready() -> void:
	pass # 현재는 특별한 초기화 없음
