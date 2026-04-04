class_name BaseSidePanelLayout
extends RefCounted


func update_scale_pivot(panel) -> void:
	if panel._visual_root:
		panel._visual_root.pivot_offset = Vector2(panel._visual_root.size.x, panel._visual_root.size.y / 2.0)


func update_position(panel, do_open: bool) -> void:
	if panel.is_embedded:
		panel.offset_left = 0.0
		panel.offset_right = 0.0
		return

	var offsets: Dictionary = get_target_offsets(panel, do_open)
	panel.offset_left = offsets.left
	panel.offset_right = offsets.right


func animate_slide(panel, do_open: bool) -> void:
	if panel.is_embedded:
		if panel._tween:
			panel._tween.kill()
		panel.visible = do_open
		update_position(panel, do_open)
		return

	if panel._tween:
		panel._tween.kill()

	var offsets: Dictionary = get_target_offsets(panel, do_open)
	if do_open:
		panel.visible = true

	panel._tween = panel.create_tween()
	panel._tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	panel._tween.tween_property(panel, "offset_left", offsets.left, panel.TWEEN_DURATION)
	panel._tween.tween_property(panel, "offset_right", offsets.right, panel.TWEEN_DURATION)

	if not do_open:
		panel._tween.set_parallel(false)
		panel._tween.tween_callback(func(): panel.visible = false)


func get_target_offsets(panel, do_open: bool) -> Dictionary:
	if panel.is_embedded:
		return {"left": 0.0, "right": 0.0}

	var panel_width: float = panel._get_panel_width()
	var closed_offset: float = get_visual_width(panel)
	var target_r: float = -get_panel_gap(panel) if do_open else closed_offset
	return {
		"left": target_r - panel_width,
		"right": target_r
	}


func get_visual_width(panel) -> float:
	var scale_x: float = panel._visual_root.scale.x if panel._visual_root else 1.0
	return panel._get_panel_width() * scale_x


func get_panel_gap(panel) -> float:
	var viewport_width: float = panel.get_viewport_rect().size.x
	return 16.0 if viewport_width < 1100.0 else panel.FLOAT_GAP


func get_vertical_margins(panel) -> Dictionary:
	var viewport_height: float = panel.get_viewport_rect().size.y
	var top: float = 100.0
	var bottom: float = 120.0

	if viewport_height < 900.0:
		top = 72.0
		bottom = 88.0
	if viewport_height < 760.0:
		top = 48.0
		bottom = 56.0
	if viewport_height < 620.0:
		top = 24.0
		bottom = 24.0

	return {"top": top, "bottom": bottom}


func refresh_layout(panel, animated: bool) -> void:
	if not panel.is_node_ready():
		return

	if panel._visual_root:
		if panel.is_embedded:
			var viewport_width: float = panel.get_viewport_rect().size.x
			var side_margin: int = int(clampf(viewport_width * 0.17, 56.0, 220.0))
			panel.custom_minimum_size.x = 0.0
			if panel._panel_container:
				panel._panel_container.custom_minimum_size.x = 0.0
			panel._visual_root.add_theme_constant_override("margin_left", side_margin)
			panel._visual_root.add_theme_constant_override("margin_top", 76)
			panel._visual_root.add_theme_constant_override("margin_right", side_margin)
			panel._visual_root.add_theme_constant_override("margin_bottom", 112)
		else:
			var panel_width: float = panel._get_panel_width()
			panel.custom_minimum_size.x = panel_width
			if panel._panel_container:
				panel._panel_container.custom_minimum_size.x = panel_width
			var vertical: Dictionary = get_vertical_margins(panel)
			panel._visual_root.add_theme_constant_override("margin_left", 0)
			panel._visual_root.add_theme_constant_override("margin_top", int(vertical.top))
			panel._visual_root.add_theme_constant_override("margin_bottom", int(vertical.bottom))
			panel._visual_root.add_theme_constant_override("margin_right", int(get_panel_gap(panel) * 0.5))
		update_scale_pivot(panel)

	if animated and panel.is_open:
		animate_slide(panel, true)
	else:
		update_position(panel, panel.is_open)


func on_viewport_resized(panel) -> void:
	refresh_layout(panel, false)
