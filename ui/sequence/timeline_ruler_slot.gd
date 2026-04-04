class_name TimelineRulerSlot
extends Control

signal beat_clicked(slot_index: int, beat_index: int, sub_index: int)

const LABEL_FONT_SIZE := 9
const ACTIVE_COLOR := ThemeColors.APP_ACCENT_GOLD
const HOVER_COLOR := Color(0.90, 0.78, 0.48, 0.22)
const BORDER_COLOR := Color(0.30, 0.22, 0.16, 0.12)
const DOWNBEAT_COLOR := Color(0.30, 0.22, 0.16, 0.28)
const SUBDIVISION_COLOR := Color(0.30, 0.22, 0.16, 0.10)
const PANEL_BG_COLOR := Color(1, 1, 1, 0.20)
const PANEL_BORDER_COLOR := Color(0.30, 0.22, 0.16, 0.08)
const PANEL_INSET := Vector2(1.0, 1.0)
const PANEL_CORNER_RADIUS := 8
const TRACK_COLOR := Color(0.42, 0.32, 0.22, 0.22)
const TRACK_ACTIVE_FILL := Color(0.93, 0.80, 0.46, 0.42)
const TRACK_Y := 14.0
const TRACK_HEIGHT := 2.0
const PLAYHEAD_WIDTH := 2.0

var slot_index: int = -1
var _total_beats: int = 4
var _subdivisions_per_beat: int = 2
var _active_beat_index: int = -1
var _active_sub_index: int = 0
var _playhead_progress: float = -1.0
var _fill_progress: float = -1.0
var _show_playhead: bool = false
var _hover_beat_index: int = -1
var _hover_sub_index: int = -1
var _dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_exited.connect(_mouse_exited)

func setup(index: int, beats: int, subdivisions_per_beat: int = 2) -> void:
	slot_index = index
	_total_beats = max(1, beats)
	_subdivisions_per_beat = max(1, subdivisions_per_beat)
	custom_minimum_size.y = 20.0
	queue_redraw()

func update_playhead(active_beat: int, active_sub: int = 0) -> void:
	_active_beat_index = active_beat
	_active_sub_index = active_sub
	_playhead_progress = -1.0
	_fill_progress = -1.0
	_show_playhead = active_beat >= 0
	queue_redraw()

func update_playhead_progress(fill_progress: float, playhead_progress: float = -1.0) -> void:
	_fill_progress = clampf(fill_progress, 0.0, 1.0)
	_show_playhead = playhead_progress >= 0.0
	_playhead_progress = clampf(playhead_progress if _show_playhead else -1.0, -1.0, 1.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = false
			_drag_start_pos = event.position
			_update_hover_from_x(event.position.x)
		else:
			if not _dragging and _hover_beat_index >= 0:
				beat_clicked.emit(slot_index, _hover_beat_index, _hover_sub_index)
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion:
		_update_hover_from_x(event.position.x)
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _dragging and event.position.distance_to(_drag_start_pos) > 4.0:
				_dragging = true
			if _dragging and _hover_beat_index >= 0:
				beat_clicked.emit(slot_index, _hover_beat_index, _hover_sub_index)
		queue_redraw()

func _mouse_exited() -> void:
	_hover_beat_index = -1
	_hover_sub_index = -1
	queue_redraw()

func _update_hover_from_x(x_pos: float) -> void:
	var total_divisions = _total_beats * _subdivisions_per_beat
	var segment_width = size.x / float(total_divisions)
	if segment_width <= 0.0:
		_hover_beat_index = -1
		_hover_sub_index = -1
		return
	var division = clampi(int(floor(x_pos / segment_width)), 0, total_divisions - 1)
	_hover_beat_index = int(floor(float(division) / float(_subdivisions_per_beat)))
	_hover_sub_index = division % _subdivisions_per_beat
	queue_redraw()

func _draw() -> void:
	var total_divisions = _total_beats * _subdivisions_per_beat
	var segment_width = size.x / float(total_divisions)
	var active_division = (_active_beat_index * _subdivisions_per_beat) + _active_sub_index
	var hover_division = (_hover_beat_index * _subdivisions_per_beat) + _hover_sub_index
	var panel_rect = Rect2(PANEL_INSET, size - (PANEL_INSET * 2.0))
	_draw_soft_box(panel_rect, PANEL_BG_COLOR, PANEL_BORDER_COLOR, PANEL_CORNER_RADIUS, 1)

	var fill_area_rect = Rect2(2.0, 4.0, size.x - 4.0, size.y - 8.0)
	_draw_soft_box(fill_area_rect, Color(1, 1, 1, 0.0), Color(0, 0, 0, 0), 2, 0)
	var track_rect = Rect2(2.0, TRACK_Y, size.x - 4.0, TRACK_HEIGHT)
	_draw_soft_box(track_rect, TRACK_COLOR, Color(0, 0, 0, 0), 2, 0)

	if _hover_beat_index >= 0:
		var hover_x = hover_division * segment_width
		var hover_rect = Rect2(hover_x, 3.0, segment_width, size.y - 6.0)
		_draw_soft_box(hover_rect, HOVER_COLOR, Color(0, 0, 0, 0), 3, 0)

	var fill_ratio := -1.0
	if _fill_progress >= 0.0:
		fill_ratio = _fill_progress
	elif _active_beat_index >= 0:
		fill_ratio = float(active_division) / float(max(total_divisions, 1))

	if fill_ratio >= 0.0:
		var fill_width = clampf(fill_area_rect.size.x * fill_ratio, 0.0, fill_area_rect.size.x)
		var fill_rect = Rect2(fill_area_rect.position, Vector2(fill_width, fill_area_rect.size.y))
		_draw_soft_box(fill_rect, TRACK_ACTIVE_FILL, Color(0, 0, 0, 0), 2, 0)

	for division in range(total_divisions):
		var left = division * segment_width
		var is_beat_boundary = division % _subdivisions_per_beat == 0
		var divider_color = DOWNBEAT_COLOR if division == 0 else (Color(0.30, 0.22, 0.16, 0.18) if is_beat_boundary else SUBDIVISION_COLOR)
		var top = 4.0 if is_beat_boundary else 8.0
		var bottom = size.y - 4.0
		draw_line(Vector2(left, top), Vector2(left, bottom), divider_color, 1.2 if is_beat_boundary else 1.0)
		if is_beat_boundary:
			var beat = int(floor(float(division) / float(_subdivisions_per_beat)))
			_draw_label(str(beat + 1), Vector2(left + 4, 12), ThemeColors.APP_TEXT_HINT)

	if _show_playhead and _playhead_progress >= 0.0:
		var playhead_x = fill_area_rect.position.x + (fill_area_rect.size.x * _playhead_progress)
		draw_line(Vector2(playhead_x, 3.0), Vector2(playhead_x, size.y - 3.0), ACTIVE_COLOR, PLAYHEAD_WIDTH)
	elif _active_beat_index >= 0:
		var playhead_x = fill_area_rect.position.x + (fill_area_rect.size.x * (float(active_division) / float(max(total_divisions, 1))))
		draw_line(Vector2(playhead_x, 3.0), Vector2(playhead_x, size.y - 3.0), ACTIVE_COLOR, PLAYHEAD_WIDTH)

	draw_line(Vector2(size.x - 1, 4.0), Vector2(size.x - 1, size.y - 4.0), SUBDIVISION_COLOR, 1.0)

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

func _draw_label(label_text: String, position: Vector2, color: Color) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE, color)
