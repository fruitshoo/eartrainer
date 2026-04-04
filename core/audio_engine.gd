# audio_engine.gd
# 오디오 엔진 싱글톤 - 기타 음 및 메트로놈 재생
extends Node

const AUDIO_ENGINE_BUSES := preload("res://core/audio_engine_buses.gd")
const AUDIO_ENGINE_PLAYBACK := preload("res://core/audio_engine_playback.gd")

# ============================================================
# ENUMS
# ============================================================
enum Tone {
	CLEAN,
	DRIVE
}

# ============================================================
# CONSTANTS - METRONOME
# ============================================================
const METRONOME_ACCENT_PITCH := 1.5
const METRONOME_NORMAL_PITCH := 1.0
const METRONOME_DURATION := 0.03
const METRONOME_FREQUENCY_ACCENT := 1200.0
const METRONOME_FREQUENCY_NORMAL := 800.0

# ============================================================
# CONSTANTS - BUS NAMES
# ============================================================
const BUS_CLEAN := "GuitarClean"
const BUS_DRIVE := "GuitarDrive"
const BUS_CHORD := "Chord"
const BUS_MELODY := "Melody"
const BUS_SFX := "SFX"

# ============================================================
# CONSTANTS - EFFECT PARAMETERS
# ============================================================
const COMP_THRESHOLD_CLEAN := -8.0
const COMP_RATIO_CLEAN := 2.5
const COMP_THRESHOLD_DRIVE := -15.0
const COMP_RATIO_DRIVE := 6.0
const COMP_ATTACK_US := 20000.0
const COMP_RELEASE_MS := 250.0
const COMP_GAIN_CLEAN := 6.0

const CHORUS_VOICE_COUNT := 2
const CHORUS_DRY := 1.0
const CHORUS_WET := 0.0
const CHORUS_RATE_HZ := 0.5
const CHORUS_DEPTH_MS := 1.5

const REVERB_CLEAN_ROOM := 0.3
const REVERB_CLEAN_DAMPING := 0.7
const REVERB_CLEAN_WET := 0.15
const REVERB_DRIVE_ROOM := 0.3
const REVERB_DRIVE_WET := 0.2

const DRIVE_AMOUNT := 0.6
const DRIVE_POST_GAIN := -2.0

# ============================================================
# RESOURCES
# ============================================================
var string_samples: Dictionary = {
	0: preload("res://assets/audio/E2.wav"),
	1: preload("res://assets/audio/A2.wav"),
	2: preload("res://assets/audio/D3.wav"),
	3: preload("res://assets/audio/G3.wav"),
	4: preload("res://assets/audio/B3.wav"),
	5: preload("res://assets/audio/E4.wav")
}

const OPEN_STRING_MIDI = [40, 45, 50, 55, 59, 64]

# ============================================================
# STATE
# ============================================================
var current_tone: Tone = Tone.CLEAN
var is_metronome_enabled: bool = false
var _bus_helper: AudioEngineBuses = AUDIO_ENGINE_BUSES.new()
var _playback_helper: AudioEnginePlayback = AUDIO_ENGINE_PLAYBACK.new()

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_setup_audio_buses()
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.beat_updated.connect(_on_beat_updated)

# ============================================================
# INTERNAL - 오디오 버스 및 이펙트 설정
# ============================================================
func _setup_audio_buses() -> void:
	_bus_helper.setup_audio_buses(self)


func _setup_chord_bus() -> void:
	_bus_helper._setup_chord_bus(self)


func _setup_melody_bus() -> void:
	_bus_helper._setup_melody_bus(self)


func _setup_routing_bus(bus_name: String) -> void:
	_bus_helper._setup_routing_bus(self, bus_name)


func _update_bus_routing() -> void:
	_bus_helper.update_bus_routing(self)


func _setup_clean_bus() -> void:
	_bus_helper._setup_clean_bus(self)


func _setup_drive_bus() -> void:
	_bus_helper._setup_drive_bus(self)

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_tile_clicked(midi_note: int, string_index: int, _modifiers: Dictionary) -> void:
	_playback_helper.on_tile_clicked(self, midi_note, string_index)


func _on_beat_updated(beat_index: int, _total_beats: int) -> void:
	_playback_helper.on_beat_updated(self, beat_index)

# ============================================================
# PUBLIC API - 톤 설정
# ============================================================
func set_tone(mode: Tone) -> void:
	_playback_helper.set_tone(self, mode)


func toggle_tone() -> void:
	_playback_helper.toggle_tone(self)

# ============================================================
# PUBLIC API - 메트로놈 제어
# ============================================================
func set_metronome_enabled(enabled: bool) -> void:
	_playback_helper.set_metronome_enabled(self, enabled)

# ============================================================
# PUBLIC API - 기타 음 재생
# ============================================================
func play_note(midi_note: int, string_index: int = -1, context: String = "chord", volume_linear: float = 1.0) -> void:
	_playback_helper.play_note(self, midi_note, string_index, context, volume_linear)


func stop_all_notes() -> void:
	_playback_helper.stop_all_notes(self)

# ============================================================
# PUBLIC API - 메트로놈 재생
# ============================================================
func play_metronome(is_accent: bool) -> void:
	await _playback_helper.play_metronome(self, is_accent)

# ============================================================
# PUBLIC API - SFX (Synthesized)
# ============================================================
func play_sfx(type: String) -> void:
	await _playback_helper.play_sfx(self, type)
