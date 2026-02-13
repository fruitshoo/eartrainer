class_name BaseSidePanel
extends Control

# ============================================================
# SIGNALS
# ============================================================
signal toggled(is_open: bool)

# ============================================================
# CONSTANTS & CONFIG
# ============================================================
const PANEL_WIDTH := 340.0 # Standard width for all side panels
const FLOAT_GAP := 24.0 # Gap from right edge
const TWEEN_DURATION := 0.3

# Layout Constants
const MARGIN_OUTER := 24
const SPACING_SECTION := 24
const SPACING_GRID_H := 16
const SPACING_GRID_V := 12

# ============================================================
# STATE
# ============================================================
var is_open: bool = false
var _tween: Tween

# UI References
var _panel_container: PanelContainer
var _content_scroll: ScrollContainer
var _content_container: VBoxContainer  # Main content area for children to populate
var _visual_root: MarginContainer # [New] Internal root for scaling

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_build_base_ui()
	_update_position(false)
	visible = false
	
	# Allow subclasses to add their specific UI
	_build_content() 

func _input(event: InputEvent) -> void:
	if not is_open: return
	
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ============================================================
# PUBLIC API
# ============================================================
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

func _update_scale_pivot() -> void:
	if _visual_root:
		# Scale from the right-center to keep it pinned to the edge
		_visual_root.pivot_offset = Vector2(_visual_root.size.x, _visual_root.size.y / 2.0)

# ============================================================
# VIRTUAL METHODS (To be overridden)
# ============================================================
func _build_content() -> void:
	pass

# ============================================================
# PRIVATE: ANIMATION & LAYOUT
# ============================================================
func _update_position(do_open: bool) -> void:
	var target_r = - FLOAT_GAP if do_open else PANEL_WIDTH
	var target_l = target_r - PANEL_WIDTH
	
	offset_left = target_l
	offset_right = target_r

func _animate_slide(do_open: bool) -> void:
	if _tween: _tween.kill()
	
	var target_r = - FLOAT_GAP if do_open else PANEL_WIDTH
	var target_l = target_r - PANEL_WIDTH
	
	if do_open: visible = true
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	_tween.tween_property(self, "offset_left", target_l, TWEEN_DURATION)
	_tween.tween_property(self, "offset_right", target_r, TWEEN_DURATION)
	
	if not do_open:
		_tween.set_parallel(false)
		_tween.tween_callback(func(): visible = false)

# ============================================================
# PRIVATE: UI BUILDER CORE
# ============================================================
func _build_base_ui() -> void:
	# 1. Main Container Setup
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 2. visual Root (Floating Panel Look)
	_visual_root = MarginContainer.new()
	_visual_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_theme_constant_override("margin_top", 100)
	_visual_root.add_theme_constant_override("margin_bottom", 120)
	_visual_root.add_theme_constant_override("margin_right", 12)
	add_child(_visual_root)
	
	# Connect resize to update pivot dynamically
	_visual_root.resized.connect(_update_scale_pivot)
	
	_panel_container = PanelContainer.new()
	_panel_container.clip_contents = true
	_panel_container.add_theme_stylebox_override("panel", _get_base_style_box("panel_bg"))
	_visual_root.add_child(_panel_container)
	
	# 3. Content Contentainer (Directly in Panel, No Scroll enforced)
	# Child classes can add a ScrollContainer here if they need it.
	var content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL # Allow full height
	content_margin.add_theme_constant_override("margin_left", MARGIN_OUTER)
	content_margin.add_theme_constant_override("margin_right", MARGIN_OUTER)
	content_margin.add_theme_constant_override("margin_top", MARGIN_OUTER)
	content_margin.add_theme_constant_override("margin_bottom", MARGIN_OUTER)
	_panel_container.add_child(content_margin)
	
	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", SPACING_SECTION)
	content_margin.add_child(_content_container)

# ============================================================
# STYLE HELPER
# ============================================================
func _get_base_style_box(type: String) -> StyleBox:
	match type:
		"empty":
			return StyleBoxEmpty.new()
		"panel_bg":
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.98, 0.98, 1, 0.75)
			sb.corner_radius_top_left = 24
			sb.corner_radius_top_right = 24
			sb.corner_radius_bottom_right = 24
			sb.corner_radius_bottom_left = 24
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(1, 1, 1, 0.5)
			sb.shadow_color = Color(0, 0, 0, 0.1)
			sb.shadow_size = 8
			return sb
	return StyleBoxEmpty.new()
