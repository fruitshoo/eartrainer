class_name PitchQuizData
extends RefCounted

const PITCH_CLASSES = {
	0: {"name": "C", "short": "C", "color": Color.ORANGE_RED}, # C
	1: {"name": "C#", "short": "C#", "color": Color.MEDIUM_PURPLE}, # C#
	2: {"name": "D", "short": "D", "color": Color.GOLD}, # D
	3: {"name": "D#", "short": "D#", "color": Color.MEDIUM_PURPLE}, # D#
	4: {"name": "E", "short": "E", "color": Color.YELLOW_GREEN}, # E
	5: {"name": "F", "short": "F", "color": Color.WEB_GREEN}, # F
	6: {"name": "F#", "short": "F#", "color": Color.MEDIUM_PURPLE}, # F#
	7: {"name": "G", "short": "G", "color": Color.CORNFLOWER_BLUE}, # G
	8: {"name": "G#", "short": "G#", "color": Color.MEDIUM_PURPLE}, # G#
	9: {"name": "A", "short": "A", "color": Color.MEDIUM_SLATE_BLUE}, # A
	10: {"name": "A#", "short": "A#", "color": Color.MEDIUM_PURPLE}, # A#
	11: {"name": "B", "short": "B", "color": Color.HOT_PINK} # B
}

static func get_pitch_info(pitch_class: int) -> Dictionary:
	return PITCH_CLASSES.get(pitch_class % 12, PITCH_CLASSES[0])
