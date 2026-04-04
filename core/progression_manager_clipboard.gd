class_name ProgressionManagerClipboard
extends RefCounted

var manager
var slot_helper

func _init(p_manager, p_slot_helper) -> void:
	manager = p_manager
	slot_helper = p_slot_helper

func copy_bar(bar_index: int) -> void:
	if bar_index < 0 or bar_index >= manager.bar_count:
		return
	manager.bar_clipboard = {
		"kind": "single",
		"bars": [slot_helper._get_bar_snapshot(bar_index).duplicate(true)],
		"source_start": bar_index,
		"source_end": bar_index,
		"next_paste_bar": bar_index
	}

func copy_bar_range(start_bar: int, end_bar: int) -> void:
	if start_bar < 0 or end_bar < 0 or start_bar >= manager.bar_count or end_bar >= manager.bar_count:
		return
	if start_bar > end_bar:
		var temp: int = start_bar
		start_bar = end_bar
		end_bar = temp

	var snapshots: Array = []
	for bar_index in range(start_bar, end_bar + 1):
		snapshots.append(slot_helper._get_bar_snapshot(bar_index).duplicate(true))

	manager.bar_clipboard = {
		"kind": "range",
		"bars": snapshots,
		"source_start": start_bar,
		"source_end": end_bar,
		"next_paste_bar": start_bar
	}

func paste_bar(bar_index: int) -> void:
	if bar_index < 0 or bar_index >= manager.bar_count:
		return
	if manager.bar_clipboard.is_empty():
		return

	var bar_snapshots: Array = []
	for i in range(manager.bar_count):
		bar_snapshots.append(slot_helper._get_bar_snapshot(i))

	var clipboard_bars: Array = _get_clipboard_bars()
	if clipboard_bars.is_empty():
		return

	for offset in range(clipboard_bars.size()):
		var target_bar: int = bar_index + offset
		if target_bar >= manager.bar_count:
			break
		bar_snapshots[target_bar] = clipboard_bars[offset].duplicate(true)

	slot_helper._apply_bar_snapshots(bar_snapshots)
	manager.bar_clipboard["next_paste_bar"] = min(bar_index + clipboard_bars.size(), manager.bar_count - 1)
	manager.save_session()

func paste_bar_range(start_bar: int, end_bar: int) -> void:
	if start_bar < 0 or end_bar < 0 or start_bar >= manager.bar_count or end_bar >= manager.bar_count:
		return
	if manager.bar_clipboard.is_empty():
		return
	if start_bar > end_bar:
		var temp: int = start_bar
		start_bar = end_bar
		end_bar = temp

	var bar_snapshots: Array = []
	for i in range(manager.bar_count):
		bar_snapshots.append(slot_helper._get_bar_snapshot(i))

	var clipboard_bars: Array = _get_clipboard_bars()
	if clipboard_bars.is_empty():
		return

	var max_paste_count: int = min(clipboard_bars.size(), (end_bar - start_bar) + 1)
	for offset in range(max_paste_count):
		bar_snapshots[start_bar + offset] = clipboard_bars[offset].duplicate(true)

	slot_helper._apply_bar_snapshots(bar_snapshots)
	manager.bar_clipboard["next_paste_bar"] = min(start_bar + clipboard_bars.size(), manager.bar_count - 1)
	manager.save_session()

func has_bar_clipboard() -> bool:
	return not manager.bar_clipboard.is_empty()

func get_bar_clipboard_length() -> int:
	return _get_clipboard_bars().size()

func get_bar_clipboard_source_range() -> Vector2i:
	if manager.bar_clipboard.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(
		int(manager.bar_clipboard.get("source_start", -1)),
		int(manager.bar_clipboard.get("source_end", -1))
	)

func get_bar_clipboard_next_paste_bar() -> int:
	if manager.bar_clipboard.is_empty():
		return -1
	return int(manager.bar_clipboard.get("next_paste_bar", -1))

func _get_clipboard_bars() -> Array:
	if manager.bar_clipboard.is_empty():
		return []
	var clipboard_bars_value = manager.bar_clipboard.get("bars", [])
	return clipboard_bars_value if clipboard_bars_value is Array else []
