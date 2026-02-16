extends Panel
class_name SequenceLoopOverlay

# ============================================================
# CONSTANTS
# ============================================================
const PADDING := 6.0

# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	_setup_style()
	visible = false

# ============================================================
# PUBLIC API
# ============================================================
func update_overlay(buttons: Array, start: int, end: int) -> void:
	# [Fix] Layout update requires waiting for the frame to finish, 
	# especially after rebuilding slots.
	await get_tree().process_frame
	
	if start == -1 or end == -1 or start >= buttons.size() or end >= buttons.size():
		visible = false
		return
		
	var start_node = buttons[start]
	var end_node = buttons[end]
	
	if not (start_node is Control) or not (end_node is Control):
		visible = false
		return
		
	visible = true
	
	# Global Position Calculation (Global Rect)
	var start_rect = start_node.get_global_rect()
	var end_rect = end_node.get_global_rect()
	
	# Merge Rects
	var full_rect = start_rect.merge(end_rect)
	
	# Expand slightly for visual padding
	full_rect = full_rect.grow(PADDING)
	
	# Apply to Panel
	global_position = full_rect.position
	custom_minimum_size = full_rect.size
	size = full_rect.size

# ============================================================
# PRIVATE METHODS
# ============================================================
func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 0.5, 0.15) # Subtle yellow
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.8, 0.2, 0.8) # Gold border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	
	add_theme_stylebox_override("panel", style)
	modulate = Color.WHITE # Reset modulate if it was set in tscn
