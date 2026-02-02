# hud_manager.gd
# HUD 표시 관리 - 재즈 전광판 스타일
extends Control

# ============================================================
# CONSTANTS
# ============================================================
const BEAT_DOT_COUNT := 4
const BEAT_DOT_ON_COLOR := Color(1.0, 0.8, 0.3, 1.0)
const BEAT_DOT_OFF_COLOR := Color(0.3, 0.3, 0.3, 0.5)

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var key_button: Button = %KeyButton
@onready var key_selector_popup: PopupPanel = %KeySelectorPopup
@onready var chord_label: Label = %ChordLabel
@onready var beat_container: HBoxContainer = %BeatContainer # 비트 도트 컨테이너
@onready var settings_button: Button = %SettingsButton # [New]
@onready var help_button: Button = %HelpButton # [New]

# Transport Controls
@onready var play_button: Button = %PlayButton
@onready var stop_button: Button = %StopButton
@onready var record_button: Button = %RecordButton
@onready var bpm_spin_box: SpinBox = %BPMSpinBox

# ============================================================
# STATE
# ============================================================
var _last_chord_text: String = ""
var _chord_tween: Tween = null
var _is_animating: bool = false
var _beat_dots: Array = []
var _current_sequencer_step: int = -1 # 시퀀서 현재 스텝 추적 (EventBus 통해 업데이트)

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	GameManager.settings_changed.connect(_update_display)
	if key_button:
		key_button.pressed.connect(_on_key_button_pressed)
		key_button.focus_mode = Control.FOCUS_NONE
	
	EventBus.beat_pulsed.connect(_on_beat_pulsed)
	EventBus.bar_changed.connect(_on_bar_changed)
	EventBus.beat_updated.connect(_on_beat_updated)
	EventBus.settings_visibility_changed.connect(_on_settings_visibility_changed)
	EventBus.debug_log.connect(_on_debug_log) # [New]
	EventBus.sequencer_playing_changed.connect(_on_sequencer_playing_changed)
	
	# Melody Managers
	var melody_manager = GameManager.get_node_or_null("MelodyManager")
	if melody_manager:
		melody_manager.recording_started.connect(_on_recording_started)
		melody_manager.recording_stopped.connect(_on_recording_stopped)
	
	if play_button:
		play_button.pressed.connect(func(): EventBus.request_toggle_playback.emit())
		play_button.focus_mode = Control.FOCUS_NONE
		
	if stop_button:
		stop_button.pressed.connect(func():
			EventBus.request_stop_playback.emit()
			# Highlight clearing is handled by bus listener usually, or we can emit reset signal
		)
		stop_button.focus_mode = Control.FOCUS_NONE
		
	if record_button:
		record_button.toggled.connect(_on_record_toggled)
		record_button.focus_mode = Control.FOCUS_NONE
		
	if bpm_spin_box:
		bpm_spin_box.value = GameManager.bpm
		bpm_spin_box.value_changed.connect(func(val): GameManager.bpm = int(val))
		# SpinBox Text Focus Disable
		var le = bpm_spin_box.get_line_edit()
		if le:
			le.focus_mode = Control.FOCUS_NONE
			le.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if settings_button:
		settings_button.pressed.connect(func(): ModalManager.toggle("settings"))
		settings_button.focus_mode = Control.FOCUS_NONE
		
	if help_button:
		help_button.pressed.connect(func(): EventBus.request_toggle_help.emit())
		help_button.focus_mode = Control.FOCUS_NONE

	# Ear Trainer Button - Uses ModalManager for toggle
	if top_right_buttons:
		var et_btn = Button.new()
		et_btn.text = "🎧"
		et_btn.tooltip_text = "Ear Training"
		et_btn.focus_mode = Control.FOCUS_NONE
		et_btn.pressed.connect(func(): ModalManager.toggle("ear_trainer"))
		top_right_buttons.add_child(et_btn)
		# Move to be second (between Help and Settings)
		# Assuming Help is 0, Settings is 1. If we add via code it appends (2).
		# Moving to 1 puts it after Help.
		# Check actual order in scene: Help, Settings.
		top_right_buttons.move_child(et_btn, 1)

	_setup_visual_style()
	_setup_beat_indicators()
	call_deferred("_delayed_setup")

func _delayed_setup() -> void:
	await get_tree().process_frame
	_update_display()

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
	if chord_label:
		chord_label.pivot_offset = chord_label.size / 2.0
		chord_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		chord_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.6, 0.2, 0.5))
		chord_label.add_theme_constant_override("shadow_offset_x", 2)
		chord_label.add_theme_constant_override("shadow_offset_y", 2)

func _setup_beat_indicators() -> void:
	if not beat_container:
		return
	
	# 기존 도트 삭제
	for child in beat_container.get_children():
		child.queue_free()
	_beat_dots.clear()
	
	# 4개의 비트 도트 생성
	for i in range(BEAT_DOT_COUNT):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(20, 20)
		dot.color = BEAT_DOT_OFF_COLOR
		beat_container.add_child(dot)
		_beat_dots.append(dot)

# ============================================================
# DISPLAY UPDATE
# ============================================================
func _update_display() -> void:
	if not key_button or not chord_label:
		return
	
	var use_flats := MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var key_name := MusicTheory.get_note_name(GameManager.current_key, use_flats)
	var mode_name := "MAJOR" if GameManager.current_mode == MusicTheory.ScaleMode.MAJOR else "MINOR"
	key_button.text = "[ %s %s ]" % [key_name, mode_name]
	
	var chord_root: int = GameManager.current_chord_root
	var chord_type: String = GameManager.current_chord_type
	
	if EventBus.is_sequencer_playing and _current_sequencer_step >= 0:
		var slot_data = ProgressionManager.get_slot(_current_sequencer_step)
		if slot_data:
			chord_root = slot_data.root
			chord_type = slot_data.type
	
	if chord_type.is_empty():
		_fade_out_chord_label()
		return
	else:
		chord_label.modulate.a = 1.0
	
	var root_name := MusicTheory.get_note_name(chord_root, use_flats)
	var new_text := "%s %s" % [root_name, chord_type]
	
	chord_label.pivot_offset = chord_label.size / 2.0
	
	if new_text != _last_chord_text:
		chord_label.text = new_text
		_animate_chord_change()
		_last_chord_text = new_text

# ============================================================
# BEAT INDICATOR
# ============================================================
func _on_beat_updated(beat_index: int, _total_beats: int) -> void:
	if beat_index < 0:
		# 시퀀서 정지 시 모든 도트 끄기
		_reset_beat_dots()
		return
	
	# 현재 박자까지 불 켜기
	for i in range(_beat_dots.size()):
		var dot: ColorRect = _beat_dots[i]
		if i <= beat_index:
			dot.color = BEAT_DOT_ON_COLOR
			# 현재 박자는 펄스 효과
			if i == beat_index:
				_pulse_dot(dot)
		else:
			dot.color = BEAT_DOT_OFF_COLOR

func _reset_beat_dots() -> void:
	for dot in _beat_dots:
		dot.color = BEAT_DOT_OFF_COLOR

func _pulse_dot(dot: ColorRect) -> void:
	var tween := create_tween()
	tween.tween_property(dot, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(dot, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# ANIMATIONS
# ============================================================
func _animate_chord_change() -> void:
	if _chord_tween and _chord_tween.is_running():
		_chord_tween.kill()
	
	_is_animating = true
	_chord_tween = create_tween()
	_chord_tween.tween_property(chord_label, "scale", Vector2(1.15, 1.15), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chord_tween.tween_property(chord_label, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_chord_tween.finished.connect(func(): _is_animating = false)

func _on_beat_pulsed() -> void:
	if not chord_label or not EventBus.is_sequencer_playing or _is_animating:
		return
	
	var pulse_tween := create_tween()
	pulse_tween.tween_property(chord_label, "scale", Vector2(1.05, 1.05), 0.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(chord_label, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_bar_changed(slot_index: int) -> void:
	_current_sequencer_step = slot_index
	_update_display()

@onready var top_right_buttons: HBoxContainer = %TopRightButtons

# ...

func _on_settings_visibility_changed(visible_state: bool) -> void:
	if top_right_buttons:
		top_right_buttons.visible = !visible_state # 설정창 열리면 버튼들 숨김

func _fade_out_chord_label() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(chord_label, "modulate:a", 0.3, 0.2)


# ============================================================
# TRANSPORT LOGIC
# ============================================================
func _on_sequencer_playing_changed(is_playing: bool) -> void:
	if play_button:
		play_button.text = "PAUSE" if is_playing else "PLAY"

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

func _on_recording_started() -> void:
	if record_button:
		record_button.set_pressed_no_signal(true)
		record_button.modulate = Color(1.0, 0.3, 0.3)

func _on_recording_stopped() -> void:
	if record_button:
		record_button.set_pressed_no_signal(false)
		record_button.modulate = Color.WHITE

func _on_key_button_pressed() -> void:
	if key_selector_popup:
		if key_selector_popup.visible:
			key_selector_popup.hide()
		else:
			key_selector_popup.popup_centered_under_control(key_button)
