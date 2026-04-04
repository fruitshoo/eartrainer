extends Button

signal melody_slot_clicked(bar_idx: int, beat_idx: int, sub_idx: int)
signal melody_slot_right_clicked(bar_idx: int, beat_idx: int, sub_idx: int)
signal melody_slot_hovered(bar_idx: int, beat_idx: int, sub_idx: int)
signal melody_slot_drag_released()
signal melody_ruler_clicked(bar_idx: int, beat_idx: int, sub_idx: int)

const GUITAR_LOW_MIDI := MusicTheory.OPEN_STRING_MIDI[0]
const GUITAR_HIGH_MIDI := MusicTheory.OPEN_STRING_MIDI[5] + 19
const RULER_HEIGHT := 0.0
const PITCH_MARGIN_TOP := 18.0
const PITCH_MARGIN_BOTTOM := 10.0
const NOTE_RADIUS := 2.2
const EVEN_BAR_BG := Color(0.985, 0.972, 0.944, 0.96)
const ODD_BAR_BG := Color(0.965, 0.944, 0.904, 0.96)
const PHRASE_BG := Color(0.950, 0.922, 0.870, 0.98)
const LANE_BORDER_COLOR := Color(0, 0, 0, 0)
const BAR_DIVIDER_COLOR := ThemeColors.SEQUENCER_DIVIDER
const PHRASE_DIVIDER_COLOR := ThemeColors.SEQUENCER_PHRASE_DIVIDER
const BEAT_DIVIDER_COLOR := Color(0.30, 0.22, 0.16, 0.08)
const NOTE_BODY_HALF_HEIGHT := 4.0
const NOTE_BODY_INSET := 2.0
const PANEL_INSET := Vector2(0.0, 1.0)
const PANEL_CORNER_RADIUS := 0
const NOTE_CORNER_RADIUS := 2
const BAR_PLAYING_MARKER := ThemeColors.APP_ACCENT_GOLD
const BAR_PLAYING_MARKER_SOFT := ThemeColors.APP_ACCENT_GOLD_SOFT

var bar_index: int = -1
var beat_index: int = -1
var sub_index: int = -1 # 0 or 1 (8th note)
var _beats_per_bar: int = 4
var _subs_per_beat: int = 2

var _is_active: bool = false
var _is_sustain: bool = false
var _note_data: Dictionary = {}
var _is_selected: bool = false
var _connect_left: bool = false
var _connect_right: bool = false
var _has_playhead: bool = false
var _is_bar_playing: bool = false

func setup(bar: int, beat: int, sub: int, beats_per_bar: int = 4, subs_per_beat: int = 2) -> void:
	bar_index = bar
	beat_index = beat
	sub_index = sub
	_beats_per_bar = beats_per_bar
	_subs_per_beat = subs_per_beat
	text = ""
	
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

func update_info(data: Dictionary) -> void:
	_note_data = data
	_is_active = not data.is_empty()
	_is_sustain = data.get("is_sustain", false)
	tooltip_text = _build_tooltip()
	
	_update_visuals()
	queue_redraw()

func _update_visuals() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.bg_color = Color(0, 0, 0, 0)
	
	if _is_selected:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = ThemeColors.APP_ACCENT_GOLD
		
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	text = ""

func _draw() -> void:
	var lane_rect = Rect2(PANEL_INSET, size - (PANEL_INSET * 2.0))
	_draw_soft_box(lane_rect, _get_lane_background_color(), LANE_BORDER_COLOR, PANEL_CORNER_RADIUS, 1)
	if _is_bar_playing:
		var bar_marker_rect = Rect2(lane_rect.position.x + 1.0, lane_rect.position.y + 1.0, lane_rect.size.x - 2.0, 2.0)
		_draw_soft_box(bar_marker_rect, BAR_PLAYING_MARKER_SOFT, Color(0, 0, 0, 0), 2, 0)

	var is_bar_start = beat_index == 0 and sub_index == 0
	var is_bar_end = beat_index == _beats_per_bar - 1 and sub_index == _subs_per_beat - 1
	var is_phrase_start = is_bar_start and bar_index % 4 == 0
	var guide_color = BEAT_DIVIDER_COLOR if sub_index == 0 else Color(0.30, 0.22, 0.16, 0.04)
	var guide_width = 1.0 if sub_index == 0 else 1.0
	draw_line(Vector2(0, 1), Vector2(0, size.y - 2), PHRASE_DIVIDER_COLOR if is_phrase_start else (BAR_DIVIDER_COLOR if is_bar_start else guide_color), 2.4 if is_phrase_start else (1.5 if is_bar_start else guide_width))
	if is_bar_end:
		draw_line(Vector2(size.x - 1, 1), Vector2(size.x - 1, size.y - 2), BAR_DIVIDER_COLOR, 1.5)
	if is_bar_start and _is_bar_playing:
		draw_line(Vector2(1, 1), Vector2(1, size.y - 2), BAR_PLAYING_MARKER, 2.0)
	if is_bar_start:
		_draw_label(str(bar_index + 1), Vector2(3, 9), 8, ThemeColors.APP_TEXT_MUTED)

	if not _is_active:
		return
	
	var center_y = size.y * 0.5
	var note_rect = _get_note_rect(center_y)
	var note_color = _get_note_color()
	
	_draw_soft_box(note_rect, note_color, Color(0, 0, 0, 0), NOTE_CORNER_RADIUS, 0)
	
	if _is_sustain:
		draw_line(Vector2(note_rect.position.x + 1.0, center_y), Vector2(note_rect.end.x - 1.0, center_y), Color(0.98, 0.99, 0.95, 0.75), 1.2)
	else:
		if _is_selected:
			var note_root = int(_note_data.get("root", 60))
			_draw_label(_get_tab_hint(note_root, int(_note_data.get("string", 0))), Vector2(4, size.y - 5), 8, ThemeColors.APP_TEXT_MUTED)
	
	if _note_data.has("sub_note") and not _is_sustain:
		var sub_marker = Rect2(Vector2(size.x * 0.68, center_y - 1.5), Vector2(maxf(size.x * 0.14, 3.0), 3.0))
		_draw_soft_box(sub_marker, Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0), 2, 0)

func _get_note_rect(center_y: float) -> Rect2:
	var left = 0.0 if _connect_left else NOTE_BODY_INSET
	var right = size.x if _connect_right else size.x - NOTE_BODY_INSET
	return Rect2(
		Vector2(left, center_y - NOTE_BODY_HALF_HEIGHT),
		Vector2(maxf(right - left, 1.0), NOTE_BODY_HALF_HEIGHT * 2.0)
	)

func _get_note_color() -> Color:
	var has_sub = _note_data.has("sub_note")
	var is_16th = _note_data.get("duration", 0.5) <= 0.25
	if has_sub:
		return ThemeColors.SEQUENCER_NOTE_PAIR
	if is_16th and not _is_sustain:
		return ThemeColors.SEQUENCER_NOTE_SHORT
	if _is_sustain:
		return ThemeColors.SEQUENCER_NOTE_SUSTAIN
	return ThemeColors.SEQUENCER_NOTE

func _get_lane_background_color() -> Color:
	if int(floor(float(bar_index) / 4.0)) % 2 == 1:
		return PHRASE_BG if bar_index % 2 == 0 else PHRASE_BG.darkened(0.08)
	return EVEN_BAR_BG if bar_index % 2 == 0 else ODD_BAR_BG

func _draw_label(label_text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_soft_box(rect: Rect2, fill_color: Color, border_color: Color, radius: int, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_corner_radius_all(radius)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	draw_style_box(style, rect)

func _get_pitch_label(midi_note: int) -> String:
	var use_flats = MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var note_name = MusicTheory.get_note_name(midi_note, use_flats).replace("#", "♯").replace("b", "♭")
	var octave = int(floor(float(midi_note) / 12.0)) - 1
	return "%s%d" % [note_name, octave]

func _get_tab_hint(midi_note: int, string_idx: int) -> String:
	var guitar_string = 6 - string_idx
	var fret = MusicTheory.get_fret_position(midi_note, string_idx)
	return "%d|%d" % [guitar_string, max(fret, 0)]

func _build_tooltip() -> String:
	if not _is_active:
		return ""
	
	var root = int(_note_data.get("root", 60))
	var string_idx = int(_note_data.get("string", 0))
	var degree = MusicTheory.get_degree_number_name(root, GameManager.current_key)
	var fret = MusicTheory.get_fret_position(root, string_idx)
	return "%s • %s • String %d Fret %d" % [
		_get_pitch_label(root),
		degree,
		6 - string_idx,
		max(fret, 0)
	]

func _on_mouse_entered() -> void:
	melody_slot_hovered.emit(bar_index, beat_index, sub_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				melody_slot_clicked.emit(bar_index, beat_index, sub_index)
			else:
				melody_slot_drag_released.emit()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				melody_slot_right_clicked.emit(bar_index, beat_index, sub_index)
			else:
				melody_slot_drag_released.emit()
			accept_event()

func set_highlight(is_selected: bool) -> void:
	_is_selected = is_selected
	_update_visuals()
	queue_redraw()

func set_roll_links(connect_left: bool, connect_right: bool) -> void:
	_connect_left = connect_left
	_connect_right = connect_right
	queue_redraw()

func set_playhead_active(is_active: bool) -> void:
	_has_playhead = is_active
	queue_redraw()

func set_bar_playing(is_playing: bool) -> void:
	_is_bar_playing = is_playing
	queue_redraw()
