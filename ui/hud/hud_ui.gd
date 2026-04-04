# hud_manager.gd
# HUD 표시 관리 - 재즈 전광판 스타일
extends Control

const HUD_UI_STYLES = preload("res://ui/hud/hud_ui_styles.gd")
const HUD_UI_BEHAVIOR = preload("res://ui/hud/hud_ui_behavior.gd")

# ============================================================
# CONSTANTS
# ============================================================
const BEAT_DOT_COUNT := 4
const BEAT_DOT_ON_COLOR := Color(1.0, 0.8, 0.3, 1.0)
const BEAT_DOT_OFF_COLOR := Color(0.3, 0.3, 0.3, 0.5)

# Icons
const ICON_PLAY = preload("res://ui/resources/icons/play.svg")
const ICON_PAUSE = preload("res://ui/resources/icons/pause.svg")
const ICON_STOP = preload("res://assets/icons/stop.svg")
const ICON_RECORD = preload("res://assets/icons/record.svg")
const ICON_METRONOME = preload("res://assets/icons/metronome.svg")
const ICON_SETTINGS = preload("res://ui/resources/icons/settings.svg")
const PILL_BG := ThemeColors.APP_BUTTON_BG
const PILL_BG_HOVER := ThemeColors.APP_BUTTON_BG_HOVER
const PILL_BG_PRESSED := ThemeColors.APP_BUTTON_BG_PRESSED
const PILL_BG_ACTIVE := ThemeColors.APP_BUTTON_BG_ACTIVE
const PILL_BORDER := ThemeColors.APP_BUTTON_BORDER
const PILL_BORDER_ACTIVE := ThemeColors.APP_BUTTON_BORDER_ACTIVE
const PILL_TEXT := ThemeColors.APP_TEXT
const TOPBAR_BG := ThemeColors.APP_PANEL_BG
const TOPBAR_BORDER := ThemeColors.APP_BORDER

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var key_button: Button = %KeyButton
@onready var chord_context_label: Label = %ChordContextLabel
@onready var key_selector_popup: PopupPanel = %KeySelectorPopup


# Transport Controls
@onready var play_button: Button = %PlayButton
@onready var stop_button: Button = %StopButton
@onready var record_button: Button = %RecordButton
@onready var bpm_label: Label = $TopBarPanel/MarginContainer/TopBar/BPMLabel
@onready var bpm_spin_box: SpinBox = %BPMSpinBox
@onready var metronome_button: Button = %MetronomeButton
@onready var settings_button: Button = %SettingsButton
@onready var sequencer_button: Button = %SequencerButton
@onready var trainer_button: Button = %TrainerButton

# ============================================================
# STATE
# ============================================================
var _last_key_mode_text: String = ""
var _last_chord_context_text: String = ""
var _chord_tween: Tween = null
var _is_animating: bool = false
var _current_sequencer_step: int = -1
var _workspace_mode: int = 0
var _style_helper: HUDUIStyles
var _behavior_helper: HUDUIBehavior

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_style_helper = HUD_UI_STYLES.new(self)
	_behavior_helper = HUD_UI_BEHAVIOR.new(self)
	_setup_signals()
	_setup_transport()
	_setup_navigation()
	
	if key_selector_popup:
		key_selector_popup.popup_hide.connect(_on_key_selector_popup_hide)
		
	_setup_visual_style()
	call_deferred("_delayed_setup")

func _setup_signals() -> void:
	GameManager.settings_changed.connect(_update_display)
	EventBus.beat_pulsed.connect(_on_beat_pulsed)
	EventBus.bar_changed.connect(_on_bar_changed)
	EventBus.beat_updated.connect(_on_beat_updated)
	EventBus.settings_visibility_changed.connect(_on_settings_visibility_changed)
	EventBus.debug_log.connect(_on_debug_log)
	EventBus.sequencer_playing_changed.connect(_on_sequencer_playing_changed)
	EventBus.request_toggle_recording.connect(_on_request_toggle_recording)
	EventBus.workspace_mode_changed.connect(_on_workspace_mode_changed)

func _setup_transport() -> void:
	_behavior_helper.setup_transport()

func _setup_navigation() -> void:
	_behavior_helper.setup_navigation()

func _delayed_setup() -> void:
	await _behavior_helper.delayed_setup()

func _on_debug_log(msg: String) -> void:
	var label = %DebugLabel
	if label:
		# Append new message with timestamp
		var time = Time.get_time_string_from_system()
		var new_line = "[%s] %s" % [time, msg]
		
		# Keep only last 5 lines to prevent overflow
		var lines = label.text.split("\n")
		# Remove empty first line if any
		if lines.size() == 1 and lines[0] == "":
			lines = []
			
		lines.append(new_line)
		if lines.size() > 5:
			lines = lines.slice(-5)
			
		label.text = "\n".join(lines)
		label.modulate.a = 1.0
		
		# Reset tween
		if _debug_tween:
			_debug_tween.kill()
		_debug_tween = create_tween()
		_debug_tween.tween_interval(5.0) # Show longer
		_debug_tween.tween_property(label, "modulate:a", 0.0, 1.0)
		_debug_tween.tween_callback(func(): label.text = "")

var _debug_tween: Tween

# ============================================================
# VISUAL SETUP
# ============================================================
func _setup_visual_style() -> void:
	_style_helper.setup_visual_style()

func _apply_pill_button_style(button: Button, compact: bool) -> void:
	_style_helper.apply_pill_button_style(button, compact)

func _build_pill_style(fill_color: Color, border_color: Color, radius: int, margin_x: int, margin_y: int, shadow_size: int) -> StyleBoxFlat:
	return _style_helper.build_pill_style(fill_color, border_color, radius, margin_x, margin_y, shadow_size)

func _on_workspace_mode_changed(mode: int) -> void:
	_behavior_helper.on_workspace_mode_changed(mode)

func _update_workspace_buttons() -> void:
	_style_helper.update_workspace_buttons()

func _apply_workspace_button_state(button: Button, is_active: bool) -> void:
	_style_helper.apply_workspace_button_state(button, is_active)

# ============================================================
# DISPLAY UPDATE
# ============================================================
# [New] Update Metronome Button Visuals
func _update_metronome_visual() -> void:
	_style_helper.update_metronome_visual()

func _update_display() -> void:
	_behavior_helper.update_display()

# _get_degree_numeral() logic moved to MusicTheory.gd

# BeatDots removed - beats now shown in sequencer slots
func _on_beat_updated(_beat_index: int, _total_beats: int) -> void:
	pass

# ============================================================
# ANIMATIONS
# ============================================================
func _animate_chord_change() -> void:
	_behavior_helper.animate_chord_change()

func _on_beat_pulsed() -> void:
	return # [Disabled] Beat pulse animation on key button removed

func _on_bar_changed(slot_index: int) -> void:
	_behavior_helper.on_bar_changed(slot_index)


# ...

func _on_settings_visibility_changed(_visible_state: bool) -> void:
	pass # Deprecated logic removed


# ============================================================
# TRANSPORT LOGIC
# ============================================================
func _on_sequencer_playing_changed(is_playing: bool) -> void:
	_behavior_helper.on_sequencer_playing_changed(is_playing)

func _on_record_toggled(toggled: bool) -> void:
	_behavior_helper.on_record_toggled(toggled)

func _on_request_toggle_recording() -> void:
	_behavior_helper.on_request_toggle_recording()

func _on_recording_started() -> void:
	_behavior_helper.on_recording_started()

func _on_recording_stopped() -> void:
	_behavior_helper.on_recording_stopped()

var _popup_hide_timestamp: int = 0

func _on_key_button_pressed() -> void:
	_behavior_helper.on_key_button_pressed()

func _on_key_selector_popup_hide() -> void:
	_behavior_helper.on_key_selector_popup_hide()

func set_ui_scale(value: float) -> void:
	await _style_helper.set_ui_scale(value)

func _update_pivot() -> void:
	_style_helper.update_pivot()
