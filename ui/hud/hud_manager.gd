extends CanvasLayer

@onready var key_label = %KeyLabel
@onready var chord_label = %ChordLabel

func _ready():
	GameManager.settings_changed.connect(update_hud)
	update_hud()

func update_hud():
	if key_label == null or chord_label == null: return
		
	var key_name = GameManager.CDE_NAMES[GameManager.current_root_note]
	
	# 현재 모드에 따라 텍스트 결정
	var mode_str = "MAJOR"
	if GameManager.current_scale_mode == GameManager.ScaleMode.MINOR:
		mode_str = "MINOR"
	
	key_label.text = "[ %s %s ]" % [key_name, mode_str]
	
	var chord_root_name = GameManager.CDE_NAMES[GameManager.current_chord_root]
	var chord_type = GameManager.current_chord_type
	
	chord_label.text = chord_root_name + " " + chord_type
	chord_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))