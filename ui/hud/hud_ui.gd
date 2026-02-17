# hud_manager.gd
# HUD 표시 관리 - 재즈 전광판 스타일
extends Control

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
const ICON_LIBRARY = preload("res://assets/icons/playlist.svg")
const ICON_TRAINER = preload("res://assets/icons/headphones.svg")
const ICON_SETTINGS = preload("res://ui/resources/icons/settings.svg")

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var key_button: Button = %KeyButton
@onready var key_selector_popup: PopupPanel = %KeySelectorPopup


# Transport Controls
@onready var play_button: Button = %PlayButton
@onready var stop_button: Button = %StopButton
@onready var record_button: Button = %RecordButton
@onready var bpm_spin_box: SpinBox = %BPMSpinBox
@onready var metronome_button: Button = %MetronomeButton
@onready var settings_button: Button = %SettingsButton
@onready var library_button: Button = %LibraryButton
@onready var trainer_button: Button = %TrainerButton

# ============================================================
# STATE
# ============================================================
var _last_chord_text: String = ""
var _chord_tween: Tween = null
var _is_animating: bool = false
var _current_sequencer_step: int = -1

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
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

func _setup_transport() -> void:
	if play_button:
		play_button.icon = ICON_PLAY
		play_button.pressed.connect(func(): EventBus.request_toggle_playback.emit())
		play_button.focus_mode = Control.FOCUS_NONE
		
	if stop_button:
		stop_button.icon = ICON_STOP
		# Properties like expand_icon, alignment should be set in .tscn
		stop_button.pressed.connect(func(): EventBus.request_stop_playback.emit())
		stop_button.focus_mode = Control.FOCUS_NONE
		
	# [Disabled] Real-time recording deactivated in favor of step input
	if record_button:
		record_button.visible = false

	if metronome_button:
		metronome_button.icon = ICON_METRONOME
		metronome_button.button_pressed = GameManager.is_metronome_enabled
		metronome_button.toggled.connect(func(toggled):
			GameManager.is_metronome_enabled = toggled
		)
		metronome_button.focus_mode = Control.FOCUS_NONE
		
	if bpm_spin_box:
		bpm_spin_box.value = GameManager.bpm
		bpm_spin_box.value_changed.connect(func(val): GameManager.bpm = int(val))
		var le = bpm_spin_box.get_line_edit()
		if le:
			le.focus_mode = Control.FOCUS_NONE
			le.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_navigation() -> void:
	if key_button:
		key_button.pressed.connect(_on_key_button_pressed)
		key_button.focus_mode = Control.FOCUS_NONE
		
	if settings_button:
		settings_button.pressed.connect(func(): EventBus.request_toggle_settings.emit())
		settings_button.focus_mode = Control.FOCUS_NONE

	if library_button:
		library_button.icon = ICON_LIBRARY
		library_button.pressed.connect(func(): EventBus.request_toggle_library.emit())
		library_button.focus_mode = Control.FOCUS_NONE

	if trainer_button:
		trainer_button.icon = ICON_TRAINER
		trainer_button.pressed.connect(func(): EventBus.request_show_side_panel_tab.emit(1))
		trainer_button.focus_mode = Control.FOCUS_NONE

func _delayed_setup() -> void:
	await get_tree().process_frame
	
	# Connect MelodyManager (Delayed to ensure existence)
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager:
		if not melody_manager.recording_started.is_connected(_on_recording_started):
			melody_manager.recording_started.connect(_on_recording_started)
		if not melody_manager.recording_stopped.is_connected(_on_recording_stopped):
			melody_manager.recording_stopped.connect(_on_recording_stopped)

	_update_display()
	_update_metronome_visual()
	
	set_ui_scale(GameManager.ui_scale)

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
	pass # Style now handled by theme

# ============================================================
# DISPLAY UPDATE
# ============================================================
# [New] Update Metronome Button Visuals
func _update_metronome_visual() -> void:
	if metronome_button:
		# Update both pressed state and visual style
		metronome_button.set_pressed_no_signal(GameManager.is_metronome_enabled)
		
		# Optional: Add color feedback if needed, but toggle state usually implies style change
		# For now, rely on Theme's toggle style, or add modulate if desired.
		if GameManager.is_metronome_enabled:
			metronome_button.modulate = Color(0.7, 1.0, 0.7) # Light Green hint
		else:
			metronome_button.modulate = Color.WHITE

func _update_display() -> void:
	# [New] Also update metronome visual in case it changed externally
	_update_metronome_visual()

	if not key_button:
		return
	
	var use_flats := MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var key_name := MusicTheory.get_note_name(GameManager.current_key, use_flats)
	var mode_name := "Major" if GameManager.current_mode == MusicTheory.ScaleMode.MAJOR else "Minor"
	
	var chord_root: int = GameManager.current_chord_root
	var chord_type: String = GameManager.current_chord_type
	
	# 재생 중이면 슬롯 데이터 우선
	if EventBus.is_sequencer_playing and _current_sequencer_step >= 0:
		var slot_data = ProgressionManager.get_slot(_current_sequencer_step)
		if slot_data:
			chord_root = slot_data.root
			chord_type = slot_data.type
	
	# 디그리 계산 (로마 숫자) - MusicTheory 유틸리티 사용
	var degree := MusicTheory.get_degree_numeral(chord_root, chord_type, GameManager.current_key)
	
	# 1줄 통합: "A Major • IIm7" 형식
	var new_text := "%s %s • %s" % [key_name, mode_name, degree]
	
	key_button.pivot_offset = key_button.size / 2.0
	
	if new_text != _last_chord_text:
		key_button.text = new_text
		_animate_chord_change()
		_last_chord_text = new_text

# _get_degree_numeral() logic moved to MusicTheory.gd

# BeatDots removed - beats now shown in sequencer slots
func _on_beat_updated(_beat_index: int, _total_beats: int) -> void:
	pass

# ============================================================
# ANIMATIONS
# ============================================================
func _animate_chord_change() -> void:
	if _chord_tween and _chord_tween.is_running():
		_chord_tween.kill()
	
	_is_animating = true
	_chord_tween = create_tween()
	_chord_tween.tween_property(key_button, "scale", Vector2(1.05, 1.05), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chord_tween.tween_property(key_button, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_chord_tween.finished.connect(func(): _is_animating = false)

func _on_beat_pulsed() -> void:
	return # [Disabled] Beat pulse animation on key button removed

func _on_bar_changed(slot_index: int) -> void:
	_current_sequencer_step = slot_index
	_update_display()


# ...

func _on_settings_visibility_changed(_visible_state: bool) -> void:
	pass # Deprecated logic removed


# ============================================================
# TRANSPORT LOGIC
# ============================================================
func _on_sequencer_playing_changed(is_playing: bool) -> void:
	if play_button:
		play_button.icon = ICON_PAUSE if is_playing else ICON_PLAY

func _on_record_toggled(toggled: bool) -> void:
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager:
		if toggled:
			if not melody_manager.is_recording:
				melody_manager.start_recording()
			
			if not EventBus.is_sequencer_playing:
				var sequencer = get_tree().get_first_node_in_group("sequencer")
				if sequencer and sequencer.has_method("start_with_count_in"):
					sequencer.start_with_count_in()
		else:
			if melody_manager.is_recording:
				melody_manager.stop_recording()

func _on_request_toggle_recording() -> void:
	if record_button:
		# Toggle the button state, which triggers _on_record_toggled
		# But if we just toggle, we need to ensure we don't double trigger if it's already in the desired state (?)
		# Actually, toggle() emits toggled signal.
		record_button.button_pressed = not record_button.button_pressed

func _on_recording_started() -> void:
	if record_button:
		record_button.set_pressed_no_signal(true)
		record_button.modulate = Color(1.0, 0.3, 0.3)

func _on_recording_stopped() -> void:
	if record_button:
		record_button.set_pressed_no_signal(false)
		record_button.modulate = Color.WHITE

var _popup_hide_timestamp: int = 0

func _on_key_button_pressed() -> void:
	if not key_selector_popup: return
	
	if key_selector_popup.visible:
		key_selector_popup.hide()
		return
	
	# [Fix] If the popup was just hidden (likely by clicking this button),
	# don't immediately re-open it.
	if Time.get_ticks_msec() - _popup_hide_timestamp < 500:
		return
		
	key_selector_popup.popup_centered_under_control(key_button)

func _on_key_selector_popup_hide() -> void:
	_popup_hide_timestamp = Time.get_ticks_msec()

func set_ui_scale(value: float) -> void:
	if not is_node_ready():
		# Retry once ready
		await ready
	
	var top_bar = %TopBarPanel
	if top_bar:
		# Connect resize only once
		if not top_bar.resized.is_connected(_update_pivot):
			top_bar.resized.connect(_update_pivot)
		
		# Apply Scale only if changed
		if not is_equal_approx(top_bar.scale.x, value):
			top_bar.scale = Vector2(value, value)
			# Apply Pivot immediately
			_update_pivot()
			GameLogger.info("HUD set_ui_scale applying: %s (Size: %s)" % [value, top_bar.size])

func _update_pivot() -> void:
	var top_bar = %TopBarPanel
	if top_bar:
		# Since it's anchored Top-Center with grow_horizontal=2, 
		# pivot at center-top (width/2, 0) is ideal for scaling.
		top_bar.pivot_offset = Vector2(top_bar.size.x / 2.0, 0)
