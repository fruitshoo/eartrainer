# MusicalPattern.gd
extends Resource
class_name MusicalPattern

@export_group("Basic Info")
@export var pattern_name: String = "New Pattern"
@export var category_tag: String = "P5" # P4, M3 등
@export_multiline var description: String = ""
@export var mnemonics: Array[String] = []

@export_group("Musical Data")
## 음정 시퀀스: "C4", "G4", "R"(쉼표), "|"(마디) 등 문자열로 입력
@export var note_sequence: Array[String] = ["C4", "G4", "|"]
## 박자 시퀀스: "4", "8", "4.", "4t", "|"(마디) 등 문자열로 입력
@export var rhythm_sequence: Array[String] = ["4", "4", "|"]
## 코드 시퀀스: "I", "V7", "|"(마디) 등 로마자 기호로 입력
@export var chord_sequence: Array[String] = ["I", "|"]

@export_group("Audio Settings")
@export_range(0.0, 1.0) var melody_volume: float = 1.0
@export_range(0.0, 1.0) var chord_pad_volume: float = 0.5
@export var preferred_degree: String = "I"