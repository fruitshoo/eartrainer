class_name SidePanelOverlays
extends RefCounted

var panel
var pending_manage_interval: int = -1
var pending_delete_song: String = ""
var example_manager_root: Control
var example_list_box: VBoxContainer
var import_overlay: Control
var import_option_button: OptionButton
var import_btn_ref: Button
var delete_overlay: Control
var delete_label_ref: Label

func _init(p_panel) -> void:
	panel = p_panel

func show_example_manager_dialog(semitones: int) -> void:
	pending_manage_interval = semitones
	if not example_manager_root:
		_create_example_manager_ui()
	_refresh_example_list()
	example_manager_root.visible = true

func show_song_import_dialog() -> void:
	if not import_overlay:
		_create_import_ui()
	import_option_button.clear()
	var song_manager = GameManager.get_node_or_null("SongManager")
	if song_manager:
		var songs = song_manager.get_song_list()
		for song in songs:
			import_option_button.add_item(song.get("title", "Untitled"))
	import_option_button.disabled = import_option_button.item_count == 0
	import_btn_ref.disabled = import_option_button.disabled
	import_overlay.visible = true

func show_delete_prompt(title: String) -> void:
	if not delete_overlay:
		_create_delete_ui()
	delete_label_ref.text = "Import successful!\n\nDelete '%s' from Library?" % title
	delete_overlay.visible = true

func get_riff_manager() -> Node:
	var riff_manager = panel.get_tree().root.find_child("RiffManager", true, false)
	if not riff_manager and GameManager.has_node("RiffManager"):
		riff_manager = GameManager.get_node("RiffManager")
	return riff_manager

func _create_example_manager_ui() -> void:
	example_manager_root = Control.new()
	example_manager_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.get_parent().add_child(example_manager_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			example_manager_root.visible = false
	)
	example_manager_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	example_manager_root.add_child(center)

	var dialog_panel := PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(400, 300)
	center.add_child(dialog_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	for edge in ["top", "left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	dialog_panel.add_child(margin)
	margin.add_child(vbox)

	var head := HBoxContainer.new()
	vbox.add_child(head)

	var title := Label.new()
	title.text = "Manage Examples"
	title.theme_type_variation = "HeaderMedium"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.flat = true
	close_btn.pressed.connect(func(): example_manager_root.visible = false)
	head.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	example_list_box = VBoxContainer.new()
	example_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(example_list_box)

	var import_button := Button.new()
	import_button.text = "+ Import Song"
	import_button.pressed.connect(show_song_import_dialog)
	vbox.add_child(import_button)

func _refresh_example_list() -> void:
	if not example_list_box:
		return
	for child in example_list_box.get_children():
		child.queue_free()

	var riff_manager = get_riff_manager()
	if not riff_manager:
		return

	var riffs = riff_manager.get_riffs_for_interval(pending_manage_interval)
	if riffs.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No examples yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		example_list_box.add_child(empty_label)
		return

	for i in range(riffs.size()):
		var riff: Dictionary = riffs[i]
		var row := HBoxContainer.new()
		example_list_box.add_child(row)

		var play := Button.new()
		play.text = "▶"
		play.flat = true
		play.pressed.connect(func(): QuizManager.play_riff_preview(riff))
		row.add_child(play)

		var title := Label.new()
		title.text = riff.get("title", "Untitled")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)

		if riff.get("source") in ["user_import", "user"]:
			var delete_btn := Button.new()
			delete_btn.text = "🗑"
			delete_btn.flat = true
			delete_btn.pressed.connect(func():
				riff_manager.delete_riff(pending_manage_interval, i, "interval")
				_refresh_example_list()
			)
			row.add_child(delete_btn)

func _create_import_ui() -> void:
	import_overlay = Control.new()
	import_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.get_parent().add_child(import_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			import_overlay.visible = false
	)
	import_overlay.add_child(dim)

	var dialog_panel := PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(350, 200)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	import_overlay.add_child(center)
	center.add_child(dialog_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	for edge in ["top", "left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	dialog_panel.add_child(margin)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Import Song"
	title.theme_type_variation = "HeaderMedium"
	vbox.add_child(title)

	import_option_button = OptionButton.new()
	vbox.add_child(import_option_button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.flat = true
	cancel.pressed.connect(func(): import_overlay.visible = false)
	actions.add_child(cancel)

	import_btn_ref = Button.new()
	import_btn_ref.text = "Import"
	import_btn_ref.pressed.connect(_on_import_confirmed)
	actions.add_child(import_btn_ref)

func _on_import_confirmed() -> void:
	if import_option_button.selected == -1:
		return
	var title = import_option_button.get_item_text(import_option_button.selected)
	import_overlay.visible = false
	var riff_manager = get_riff_manager()
	if riff_manager and riff_manager.import_song_as_riff(pending_manage_interval, title):
		_refresh_example_list()
		pending_delete_song = title
		show_delete_prompt(title)

func _create_delete_ui() -> void:
	delete_overlay = Control.new()
	delete_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.get_parent().add_child(delete_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_overlay.add_child(dim)

	var dialog_panel := PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(350, 180)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_overlay.add_child(center)
	center.add_child(dialog_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	for edge in ["top", "left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	dialog_panel.add_child(margin)
	margin.add_child(vbox)

	delete_label_ref = Label.new()
	delete_label_ref.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(delete_label_ref)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 16)
	vbox.add_child(actions)

	var keep := Button.new()
	keep.text = "Keep"
	keep.flat = true
	keep.pressed.connect(func(): delete_overlay.visible = false)
	actions.add_child(keep)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func():
		var song_manager = GameManager.get_node_or_null("SongManager")
		if song_manager:
			song_manager.delete_song(pending_delete_song)
		delete_overlay.visible = false
	)
	actions.add_child(delete_btn)
