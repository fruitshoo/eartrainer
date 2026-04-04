class_name SequenceUIBarClipboard
extends RefCounted

var panel

func _init(p_panel) -> void:
	panel = p_panel

func get_copy_target_bar() -> int:
	var active_bar: int = panel._get_active_bar_index()
	if active_bar >= 0:
		return active_bar
	var loop_bar_range: Vector2i = ProgressionManager.get_loop_bar_range()
	if loop_bar_range.x >= 0:
		return loop_bar_range.x
	return -1

func copy_selected_bar() -> void:
	var loop_bar_range: Vector2i = ProgressionManager.get_loop_bar_range()
	if loop_bar_range.x >= 0 and loop_bar_range.y > loop_bar_range.x:
		ProgressionManager.copy_bar_range(loop_bar_range.x, loop_bar_range.y)
		return

	var active_bar: int = get_copy_target_bar()
	if active_bar < 0:
		return
	ProgressionManager.copy_bar(active_bar)

func paste_to_selected_bar() -> void:
	var loop_bar_range: Vector2i = ProgressionManager.get_loop_bar_range()
	if loop_bar_range.x >= 0 and loop_bar_range.y > loop_bar_range.x and ProgressionManager.get_bar_clipboard_length() > 1:
		var target_start: int = loop_bar_range.x
		var target_end: int = loop_bar_range.y
		var source_range: Vector2i = ProgressionManager.get_bar_clipboard_source_range()
		var next_paste_bar: int = ProgressionManager.get_bar_clipboard_next_paste_bar()
		var clipboard_len: int = ProgressionManager.get_bar_clipboard_length()
		if source_range == loop_bar_range and next_paste_bar > source_range.x:
			target_start = next_paste_bar
			target_end = min((target_start + clipboard_len) - 1, ProgressionManager.bar_count - 1)
		ProgressionManager.paste_bar_range(target_start, target_end)
		return

	var active_bar: int = get_copy_target_bar()
	if active_bar < 0:
		return
	if ProgressionManager.get_bar_clipboard_length() > 0:
		var source_range_single: Vector2i = ProgressionManager.get_bar_clipboard_source_range()
		var next_single: int = ProgressionManager.get_bar_clipboard_next_paste_bar()
		if active_bar == source_range_single.x and next_single > source_range_single.x:
			active_bar = next_single
	ProgressionManager.paste_bar(active_bar)
