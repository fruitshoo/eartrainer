# slot_button.gd
class_name SlotButton
extends Button

const DEGREE_FONT_SIZE := 36
const QUALITY_FONT_SIZE := 11
const ROOT_FONT_SIZE := 12
const LABEL_COLOR := ThemeColors.APP_TEXT
const SECONDARY_LABEL_COLOR := ThemeColors.APP_TEXT_MUTED
const LANE_BG_COLOR := Color(0.95, 0.92, 0.87, 0.92)
const LANE_BG_COLOR_PHRASE := Color(0.93, 0.89, 0.83, 0.94)
const CLIP_COLOR := Color(0.96, 0.94, 0.90, 0.98)
const CLIP_COLOR_NON_DIATONIC := Color(0.94, 0.90, 0.86, 0.98)
const CLIP_BORDER_COLOR := Color(0.30, 0.22, 0.16, 0.10)
const BAR_LINE_COLOR := ThemeColors.SEQUENCER_DIVIDER
const PHRASE_LINE_COLOR := ThemeColors.SEQUENCER_PHRASE_DIVIDER
const LOOP_OVERLAY := ThemeColors.SEQUENCER_LOOP
const SELECTION_OUTLINE := ThemeColors.APP_ACCENT_GOLD
const SELECTION_PANEL_TINT := Color(0.95, 0.82, 0.46, 0.16)
const SELECTION_CLIP_TINT := Color(0.95, 0.82, 0.46, 0.08)
const BAR_PLAYING_MARKER := ThemeColors.APP_ACCENT_GOLD
const BAR_PLAYING_MARKER_SOFT := ThemeColors.APP_ACCENT_GOLD_SOFT
const BAR_PLAYING_PANEL_TINT := Color(0.95, 0.76, 0.34, 0.12)
const BAR_PLAYING_CLIP_TINT := Color(0.95, 0.76, 0.34, 0.06)
const PANEL_INSET := Vector2(0.0, 2.0)
const CLIP_INSET := Vector2(1.0, 4.0)
const PANEL_CORNER_RADIUS := 0
const CLIP_CORNER_RADIUS := 0

# ============================================================
# STATE
# ============================================================
var slot_index: int = -1
var _show_beat_strip: bool = true
var _time_context_label: String = ""
var _display_degree: String = "—"
var _display_quality: String = ""
var _display_root_name: String = ""
var _is_diatonic: bool = true
var _has_data: bool = false
var _bar_index: int = -1
var _slot_in_bar: int = 0
var _slots_in_bar: int = 1

# ============================================================
# NODES
# ============================================================
@onready var beat_container: HBoxContainer = $BeatContainer

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func(): slot_pressed.emit(slot_index))
	_apply_base_button_style()
	_apply_compact_layout()

func _apply_base_button_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)

func _apply_compact_layout() -> void:
	if beat_container:
		beat_container.visible = false
		beat_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_show_beat_strip(show: bool) -> void:
	_show_beat_strip = show
	if is_node_ready():
		_apply_compact_layout()

func set_time_context(label_text: String) -> void:
	_time_context_label = label_text
	_update_tooltip()

func set_bar_context(bar_index: int, slot_in_bar: int, slots_in_bar: int) -> void:
	_bar_index = bar_index
	_slot_in_bar = slot_in_bar
	_slots_in_bar = max(1, slots_in_bar)
	queue_redraw()

# ============================================================
# PUBLIC API
# ============================================================
signal beat_clicked(slot_index: int, beat_index: int)
signal slot_pressed(index: int)

var beat_tick_scene: PackedScene = preload("res://ui/sequence/beat_tick.tscn")
var _total_beats: int = 4

var _active_beat_index: int = -1
var _hover_beat_index: int = -1

## [Updated] beats 인자 추가
func setup(index: int, beats: int = 4) -> void:
	slot_index = index
	_total_beats = beats
	text = ""
	
	# 비트 틱 생성
	for child in beat_container.get_children():
		child.queue_free()
		
	_update_default_visual()
	queue_redraw()

func update_playhead(active_beat: int) -> void:
	_active_beat_index = active_beat
	queue_redraw()

var _is_selected: bool = false
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 4.0

func _on_tick_gui_input(event: InputEvent, beat_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = false
				_drag_start_pos = event.position
			else:
				# Mouse Up (Tap)
				if not _is_dragging:
					if _is_selected:
						beat_clicked.emit(slot_index, beat_idx)
					else:
						# If not selected, clicking a beat selects the slot
						slot_pressed.emit(slot_index)
				_is_dragging = false
			accept_event()
			
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_clicked.emit(slot_index)
			accept_event()
			
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _is_dragging:
				if event.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
					_is_dragging = true
			
			if _is_dragging:
				# Scrubbing logic: Emit beat_clicked immediately
				beat_clicked.emit(slot_index, beat_idx)
				# Also ensure we highlight this beat during drag
				_on_tick_mouse_entered(beat_idx)
				accept_event()

func _on_tick_mouse_entered(beat_idx: int) -> void:
	_hover_beat_index = beat_idx
	queue_redraw()
	
	# Support dragging across multiple ticks
	if _is_dragging:
		beat_clicked.emit(slot_index, beat_idx)

func _on_tick_mouse_exited(_beat_idx: int) -> void:
	_hover_beat_index = -1
	queue_redraw()

func update_info(data: Dictionary) -> void:
	if data == null or data.is_empty():
		_update_default_visual()
		return

	var use_flats := MusicTheory.should_use_flats(GameManager.current_key, GameManager.current_mode)
	var root_name := MusicTheory.get_note_name(data.root, use_flats)
	var degree := MusicTheory.get_degree_label(data.root, GameManager.current_key, GameManager.current_mode, str(data.type))
	
	_display_degree = degree
	_display_quality = str(data.type)
	_display_root_name = "%s%s" % [root_name, str(data.type)]
	_has_data = true
	_is_diatonic = _compute_is_diatonic(int(data.root), str(data.type))
	_update_tooltip()
	queue_redraw()

func _compute_is_diatonic(chord_root: int, chord_type: String) -> bool:
	if not MusicTheory.is_in_scale(chord_root, GameManager.current_key, GameManager.current_mode):
		return false
	var expected = MusicTheory.get_diatonic_type(chord_root, GameManager.current_key, GameManager.current_mode)
	if chord_type == expected:
		return true
	if chord_type == "5" and expected != "m7b5" and expected != "dim7":
		return true
	return false

# Updated state management
var _is_playing: bool = false
var _is_in_loop: bool = false
var _is_bar_playing: bool = false

func set_state(playing: bool, selected: bool, in_loop: bool, bar_playing: bool = false) -> void:
	_is_playing = playing
	_is_selected = selected
	_is_in_loop = in_loop
	_is_bar_playing = bar_playing
	
	_update_visual_state()

func _update_visual_state() -> void:
	queue_redraw()

func _update_default_visual() -> void:
	_display_degree = "—"
	_display_quality = ""
	_display_root_name = ""
	_has_data = false
	_is_diatonic = true
	_update_tooltip()
	queue_redraw()

func _update_tooltip() -> void:
	var lines: Array[String] = []
	if not _time_context_label.is_empty():
		lines.append(_time_context_label)

	if _has_data:
		lines.append("Click to select this chord bar.")
		lines.append("Left-click a fret to replace the root.")
		lines.append("Right-click a fret for chord type options.")
	else:
		lines.append("Click to select this empty bar.")
		lines.append("Left-click a fret to add a chord.")
		lines.append("Right-click a fret for chord type options.")

	lines.append("Right-click the bar to split or merge it.")
	tooltip_text = "\n".join(lines)

signal right_clicked(index: int)

func _draw() -> void:
	var panel_rect = Rect2(PANEL_INSET, size - (PANEL_INSET * 2.0))
	_draw_soft_box(panel_rect, _get_lane_background_color(), Color(1, 1, 1, 0.0), PANEL_CORNER_RADIUS, 0)
	if _is_bar_playing:
		_draw_soft_box(panel_rect, BAR_PLAYING_PANEL_TINT, Color(0, 0, 0, 0), PANEL_CORNER_RADIUS, 0)
	if _is_selected:
		_draw_soft_box(panel_rect, SELECTION_PANEL_TINT, Color(0, 0, 0, 0), PANEL_CORNER_RADIUS, 0)
	if _is_bar_playing:
		var bar_marker_rect = Rect2(panel_rect.position.x + 1.0, panel_rect.position.y + 1.0, panel_rect.size.x - 2.0, 3.0)
		_draw_soft_box(bar_marker_rect, BAR_PLAYING_MARKER_SOFT, Color(0, 0, 0, 0), 2, 0)
	var clip_rect = Rect2(CLIP_INSET, size - (CLIP_INSET * 2.0))
	var clip_color = CLIP_COLOR if _is_diatonic else CLIP_COLOR_NON_DIATONIC
	if _has_data:
		_draw_soft_box(clip_rect, clip_color, CLIP_BORDER_COLOR, CLIP_CORNER_RADIUS, 1)
		if _is_bar_playing:
			_draw_soft_box(clip_rect, BAR_PLAYING_CLIP_TINT, Color(0, 0, 0, 0), CLIP_CORNER_RADIUS, 0)
		if _is_selected:
			_draw_soft_box(clip_rect, SELECTION_CLIP_TINT, Color(0, 0, 0, 0), CLIP_CORNER_RADIUS, 0)
		if _is_in_loop:
			_draw_soft_box(clip_rect, LOOP_OVERLAY, Color(0, 0, 0, 0), CLIP_CORNER_RADIUS, 0)
		if _is_selected:
			_draw_soft_box(clip_rect.grow(0.5), Color(0, 0, 0, 0), SELECTION_OUTLINE, CLIP_CORNER_RADIUS + 1, 2)
		var degree_width = _measure_label_width(_display_degree, DEGREE_FONT_SIZE)
		var degree_x = clip_rect.position.x + ((clip_rect.size.x - degree_width) * 0.5)
		var degree_y = clip_rect.position.y + 26.0
		_draw_label(_display_degree, Vector2(degree_x, degree_y), DEGREE_FONT_SIZE, LABEL_COLOR)
		if not _display_quality.is_empty():
			var quality_width = _measure_label_width(_display_quality, QUALITY_FONT_SIZE)
			var quality_x = clip_rect.position.x + clip_rect.size.x - quality_width - 5.0
			_draw_label(_display_quality, Vector2(quality_x, clip_rect.position.y + 13.0), QUALITY_FONT_SIZE, SECONDARY_LABEL_COLOR)
	else:
		_draw_soft_box(clip_rect, ThemeColors.APP_PANEL_BG_SOFT, Color(0.30, 0.22, 0.16, 0.08), CLIP_CORNER_RADIUS, 1)
		if _is_bar_playing:
			_draw_soft_box(clip_rect, BAR_PLAYING_CLIP_TINT, Color(0, 0, 0, 0), CLIP_CORNER_RADIUS, 0)
		if _is_selected:
			_draw_soft_box(clip_rect, SELECTION_CLIP_TINT, Color(0, 0, 0, 0), CLIP_CORNER_RADIUS, 0)
		if _is_selected:
			_draw_soft_box(clip_rect.grow(0.5), Color(0, 0, 0, 0), SELECTION_OUTLINE, CLIP_CORNER_RADIUS + 1, 2)
		var empty_width = _measure_label_width("—", DEGREE_FONT_SIZE)
		var empty_x = clip_rect.position.x + ((clip_rect.size.x - empty_width) * 0.5)
		_draw_label("—", Vector2(empty_x, clip_rect.position.y + 28.0), DEGREE_FONT_SIZE, ThemeColors.APP_TEXT_HINT)

	if _slot_in_bar == 0:
		var bar_label_color = ThemeColors.APP_TEXT if _is_bar_playing else ThemeColors.APP_TEXT_HINT
		_draw_label(str(_bar_index + 1), Vector2(4, 11), 8, bar_label_color)
	if _slot_in_bar == 0 and _bar_index % 4 == 0:
		draw_line(Vector2(0, 2), Vector2(0, size.y - 2), PHRASE_LINE_COLOR, 2.5)

	var segment_width = size.x / float(max(_total_beats, 1))
	for beat in range(_total_beats + 1):
		var x = min(size.x - 1.0, beat * segment_width)
		var line_color = BAR_LINE_COLOR if beat == 0 else Color(0, 0, 0, 0)
		draw_line(Vector2(x, 4), Vector2(x, size.y - 4), line_color, 1.0)
	if _active_beat_index >= 0:
		var playhead_x = min(size.x - 2.0, (_active_beat_index + 1) * segment_width)
		draw_line(Vector2(playhead_x, 3), Vector2(playhead_x, size.y - 3), SELECTION_OUTLINE, 2.0)


func _get_lane_background_color() -> Color:
	return LANE_BG_COLOR_PHRASE if _bar_index >= 0 and int(floor(float(_bar_index) / 4.0)) % 2 == 1 else LANE_BG_COLOR

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

func _draw_label(label_text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _measure_label_width(label_text: String, font_size: int) -> float:
	var font = get_theme_default_font()
	if font == null:
		return 0.0
	return font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(slot_index)
		accept_event()
