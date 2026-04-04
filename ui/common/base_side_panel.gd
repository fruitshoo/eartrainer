class_name BaseSidePanel
extends Control

const BASE_SIDE_PANEL_LAYOUT := preload("res://ui/common/base_side_panel_layout.gd")
const BASE_SIDE_PANEL_STYLES := preload("res://ui/common/base_side_panel_styles.gd")

signal toggled(is_open: bool)

const PANEL_WIDTH := 340.0
const FLOAT_GAP := 24.0
const TWEEN_DURATION := 0.3

const MARGIN_OUTER := 24
const SPACING_SECTION := 24
const SPACING_GRID_H := 16
const SPACING_GRID_V := 12

var is_open: bool = false
var is_embedded: bool = false
var _tween: Tween

var _panel_container: PanelContainer
var _content_scroll: ScrollContainer
var _content_container: VBoxContainer
var _visual_root: MarginContainer

var _layout_helper: BaseSidePanelLayout = BASE_SIDE_PANEL_LAYOUT.new()
var _style_helper: BaseSidePanelStyles = BASE_SIDE_PANEL_STYLES.new()


func _ready() -> void:
	_build_base_ui()
	get_tree().get_root().size_changed.connect(_on_viewport_resized)
	_update_position(false)
	visible = false
	_build_content()


func _input(event: InputEvent) -> void:
	if not is_open or is_embedded:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	set_open(true)


func close() -> void:
	set_open(false)


func set_open(do_open: bool) -> void:
	if is_open != do_open:
		is_open = do_open
		_animate_slide(do_open)
		toggled.emit(do_open)
		EventBus.settings_visibility_changed.emit(do_open)


func set_ui_scale(value: float) -> void:
	if not is_node_ready():
		await ready

	if _visual_root:
		_visual_root.scale = Vector2(value, value)
		_update_scale_pivot()
		_refresh_layout(false)


func set_embedded_mode(enabled: bool) -> void:
	is_embedded = enabled
	if is_node_ready():
		if is_embedded:
			set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		else:
			set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_refresh_layout(false)


func _update_scale_pivot() -> void:
	_layout_helper.update_scale_pivot(self)


func _build_content() -> void:
	pass


func _get_panel_width() -> float:
	var viewport_width := get_viewport_rect().size.x
	return clampf(viewport_width * 0.30, 280.0, PANEL_WIDTH)


func _update_position(do_open: bool) -> void:
	_layout_helper.update_position(self, do_open)


func _animate_slide(do_open: bool) -> void:
	_layout_helper.animate_slide(self, do_open)


func _get_target_offsets(do_open: bool) -> Dictionary:
	return _layout_helper.get_target_offsets(self, do_open)


func _get_visual_width() -> float:
	return _layout_helper.get_visual_width(self)


func _get_panel_gap() -> float:
	return _layout_helper.get_panel_gap(self)


func _get_vertical_margins() -> Dictionary:
	return _layout_helper.get_vertical_margins(self)


func _refresh_layout(animated: bool) -> void:
	_layout_helper.refresh_layout(self, animated)


func _on_viewport_resized() -> void:
	_layout_helper.on_viewport_resized(self)


func _build_base_ui() -> void:
	_style_helper.build_base_ui(self)


func _get_base_style_box(type: String) -> StyleBox:
	return _style_helper.get_base_style_box(type)
