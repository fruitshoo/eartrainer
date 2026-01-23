@tool
extends Resource
class_name MusicalPattern

## MusicalPattern (Version 0.2)
## 청음 훈련 및 멜로디 시퀀싱을 위한 데이터 구조체
## 문자열 기반의 멜로디, 리듬, 코드 표기법을 사용하여 유연성을 확보함.

# ============================================================
# BASIC INFORMATION
# ============================================================
@export_group("Basic Info")
@export var pattern_name: String = "New Pattern"
@export var category_tag: String = "P5" # P4, M3, Interval, Scale, Melody 등
@export_multiline var description: String = ""
@export var mnemonics: Array[String] = []

# ============================================================
# MUSICAL DATA (Text-based Sequencing)
# ============================================================
@export_group("Musical Data")

## 멜로디 시퀀스
## - 노트: "C4", "F#3", "Bb4" 등 과학적 표기법
## - 쉼표: "R"
## - 마디 구분: "|"
## 예: ["C4", "E4", "G4", "|", "C5"]
@export var note_sequence: Array[String] = []

## 리듬 시퀀스 (Melody와 1:1 매칭 권장)
## - 길이: "1"(온음표), "2"(2분), "4"(4분), "8"(8분), "16"(16분)
## - 점: "4." (점 4분음표)
## - 셋잇단: "4t" (4분 셋잇단)
## - 마디 구분: "|" (시각적 정렬용, 실제 길이는 0)
@export var rhythm_sequence: Array[String] = []

## 화성 진행 (코드)
## - 로마자 표기: "I", "V7", "iv", "bVII"
## - 마디 구분: "|"
@export var chord_sequence: Array[String] = []

# ============================================================
# PLAYBACK SETTINGS
# ============================================================
@export_group("Audio Settings")
@export_range(0.0, 2.0) var melody_volume: float = 1.0
@export_range(0.0, 2.0) var chord_pad_volume: float = 0.5
@export var preferred_degree: String = "I" # 훈련 시 기준이 될 중심 화성 (예: I도에서 시작)
