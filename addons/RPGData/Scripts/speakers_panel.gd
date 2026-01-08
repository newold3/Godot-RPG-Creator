@tool
extends BasePanelData


func _ready() -> void:
	disable_right_panel.connect(clear)
	super()
	default_data_element = RPGSpeaker.new()
	
	var nodes = [%LabelT1, %LabelT2, %LabelT3, %LabelT4, %LabelT5, %LabelT6]
	for obj in nodes:
		obj.visible = true


func set_data(data: Array) -> void:
	locked_items.clear()
	super(data)


func get_data() -> RPGSpeaker:
	if not data: return null
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	return data[current_selected_index]


func fill_main_list(selected_index: int) -> void:

	var node: ItemList = %MainList

	if selected_index == -1 and node.is_anything_selected():
		selected_index = node.get_selected_items()[0]
	node.clear()

	for i in range(1, data.size()):
		var id = str(i).pad_zeros(str(data.size()-1).length())
		
		var data_name = id + ": " + get_character_name(data[i].name)
		node.add_item(data_name)

	if selected_index >= 0 and node.get_item_count() > selected_index:
		node.select(selected_index)
		node.multi_selected.emit(selected_index, true)
		node.ensure_current_is_visible()
		%RemoveDataButton.set_disabled(locked_items.has(selected_index))
	elif node.get_item_count() == 0:
		%RemoveDataButton.set_disabled(true)

	if !node.is_anything_selected():
		disable_right_panel.emit()
		is_disabled = true


func _update_data_fields() -> void:
	var current_data = get_data()

	update_name()
	%TypeFx.text = tr("Select Type Fx") if !current_data.text_fx.filename else current_data.text_fx.filename.get_file()
	%TextColor.set_color(current_data.text_color)
	update_character()
	update_face()
	%FontSize.value = current_data.font_size
	%BoldText.set_pressed(current_data.text_bold)
	%ItalicText.set_pressed(current_data.text_italic)
	%WaitOnFinish.value = current_data.wait_on_finish
	%Position.select(current_data.character_position)
	%Notes.text = str(current_data.notes)
	set_font_button_name()


func set_font_button_name() -> void:
	var node = %FontName
	var font_name = get_data().font_name.get_file()
	if not font_name.is_empty():
		node.text = tr("Select Font" + " (" + font_name + ")")
	else:
		node.text = tr("Select Font (Default Selected)")


func _on_character_position_item_selected(index: int) -> void:
	get_data().character_position = index


func _on_name_and_face_position_item_selected(index: int) -> void:
	get_data().name_and_face_position = index


func _on_type_fx_middle_click_pressed() -> void:
	get_data().text_fx.filename = ""
	%TypeFx.text = tr("Select Type Fx")


func _on_type_fx_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var current_data = get_data()
	var commands: Array[RPGEventCommand]
	var command = RPGEventCommand.new(
		0, 0, {
			"path": current_data.text_fx.filename,
			"volume": current_data.text_fx.volume_db,
			"pitch": current_data.text_fx.pitch_scale,
			"pitch2": current_data.text_fx.random_pitch_scale
		}
	)
	commands.append(command)
	dialog.enable_random_pitch()
	dialog.set_parameters(commands)
	dialog.set_data()
	dialog.command_changed.connect(_on_type_fx_selected)


func _on_type_fx_selected(commands: Array[RPGEventCommand]) -> void:
	if commands.size() > 0:
		var command_data = commands[0].parameters
		var path = command_data.get("path", "")
		var volume = command_data.get("volume", 0)
		var pitch = command_data.get("pitch", 1)
		var pitch2 = command_data.get("pitch2", 1)
		if path:
			var current_data = get_data()
			current_data.text_fx.filename = path
			current_data.text_fx.volume_db = volume
			current_data.text_fx.pitch_scale = pitch
			current_data.text_fx.random_pitch_scale = pitch2
			%TypeFx.text = path.get_file()


func _on_name_middle_click_pressed() -> void:
	get_data().name.clear()
	update_name()


func _on_name_pressed() -> void:
	var type = int(get_data().name.get("type", 0))
	var value = str(get_data().name.get("val", ""))
	var pos = int(get_data().name.get("pos", 0))
	_on_show_name_box_pressed(type, value, pos)


func _on_show_name_box_pressed(type: int = 0, value: String = "", pos: int = 0) -> void:
	var path = "res://addons/CustomControls/Dialogs/show_name_box.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	dialog.set_data(type, value, pos)
	dialog.command_selected.connect(_on_name_box_selected)


func _on_name_box_selected(type: int, value: Variant, pos: int) -> void:
	var name_data = {"type": type, "val": value, "pos": pos}
	get_data().name = name_data
	update_name()


func update_name() -> void:
	var current_name = get_data().name
	
	var final_name_string = get_character_name(current_name)
	%Name.text = final_name_string if final_name_string else tr("Select Name")
	
	var speaker_id = str(current_selected_index).pad_zeros(str(data.size()-1).length())
	var data_name = speaker_id + ": " + (%Name.text if final_name_string else "")
	%MainList.set_item_text(current_selected_index-1, data_name)


func get_character_name(current_name: Dictionary) -> String:
	var id = int(current_name.get("type", 0))
	var final_name_string = ""
	if id == 0:
		final_name_string = str(current_name.get("val", ""))
	elif id == 1:
		var actor_id = int(current_name.get("val", 1))
		if RPGSYSTEM.database.actors.size() > actor_id:
			final_name_string = RPGSYSTEM.database.actors[actor_id].name
		if !final_name_string:
			final_name_string = "Actor %s" % actor_id
	elif id == 2:
		var enemy_id =  int(current_name.get("val", 1))
		if RPGSYSTEM.database.enemies.size() > enemy_id:
			final_name_string = RPGSYSTEM.database.enemies[enemy_id].name
		if !final_name_string:
			final_name_string = "Enemy %s" % enemy_id
		
	return final_name_string


func _on_text_color_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Text Color")
	dialog.color_selected.connect(_on_text_color_selected)
	dialog.set_color(%TextColor.get_color())


func _on_text_color_selected(color: Color) -> void:
	get_data().text_color = color
	%TextColor.set_color(color)


func clear() -> void:
	%Name.text = tr("Select Name")
	%TypeFx.text = tr("Select Type Fx")
	%TextColor.set_color(Color("#4d4d4d"))
	%FacePicker.set_icon("", Rect2())
	%CharacterPicker.set_icon("")
	%RemoveDataButton.set_disabled(true)


func _on_face_picker_remove_requested() -> void:
	get_data().face.clear()
	update_face()


func _on_face_picker_clicked() -> void:
	_on_image_pressed(get_data().face, "face")


func _on_character_picker_remove_requested() -> void:
	get_data().character.clear()
	update_character()


func _on_character_picker_clicked() -> void:
	_on_image_pressed(get_data().character, "character")


func _on_image_pressed(img: Dictionary = {}, target_id: String = "") -> void:
	var path = "res://addons/CustomControls/Dialogs/select_dialog_text_image.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if !img:
		img = AdvancedTextEditor.cache["image"]

	dialog.set_data(img)

	if target_id == "face":
		dialog.set_face_mode()
	else:
		dialog.set_character_mode()
	dialog.image_selected.connect(_on_image_selected.bind(target_id))


func _on_image_selected(img: Dictionary, target_id: String = "") -> void:
	img.is_speaker = true
	get_data().set(target_id, img.duplicate(true))

	img.erase("is_speaker")
	img.path = ""
	img.width = 0
	img.height = 0
	AdvancedTextEditor.cache["image"] = img
	
	var method_name = "update_%s" % target_id
	call(method_name)


func update_face() -> void:
	var face_data = get_data().face
	var image_data = face_data.get("path", RPGIcon.new())
	if ResourceLoader.exists(image_data.path):
		%FacePicker.set_icon(image_data.path, image_data.region)
	else:
		%FacePicker.set_icon("", Rect2())


func update_character() -> void:
	var character_data = get_data().character
	var image_data = character_data.get("path", RPGIcon.new())
	var path = image_data.path
	if ResourceLoader.exists(path):
		%CharacterPicker.set_icon(path)
	else:
		%CharacterPicker.set_icon("")


func _on_font_name_middle_click_pressed() -> void:
	get_data().font_name = ""
	set_font_button_name()


func _on_font_name_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _on_font_selected
	dialog.set_dialog_mode(0)
	
	dialog.set_file_selected(get_data().font_name)
	
	dialog.fill_files("fonts")


func _on_font_selected(path: String) -> void:
	get_data().font_name = path
	set_font_button_name()


func _on_font_size_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().font_size = value


func _on_bold_text_toggled(toggled_on: bool) -> void:
	get_data().text_bold = toggled_on


func _on_italic_text_toggled(toggled_on: bool) -> void:
	get_data().text_italic = toggled_on


func _on_wait_on_finish_value_changed(value: float) -> void:
	get_data().wait_on_finish = value


func _on_position_item_selected(index: int) -> void:
	get_data().character_position = index


func _on_notes_text_changed() -> void:
	get_data().notes = %Notes.text


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_face_picker_custom_copy(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	var image_data = get_data().face
	if not image_data.path.is_empty():
		clipboard[clipboard_key] = get_data().face.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)


func _on_face_picker_custom_paste(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	var image_data = clipboard.get(clipboard_key, {})
	if image_data:
		if "image_type" in clipboard[clipboard_key]:
			if clipboard[clipboard_key].image_type == 0:
				get_data().face = image_data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			else:
				if "path" in image_data:
					get_data().face.path = image_data.path
					
		elif "icon" in clipboard[clipboard_key]:
			var face = get_data().face
			if "path" in face:
				face.path.path = clipboard[clipboard_key].icon.get_path()
				face.path.region = clipboard[clipboard_key].region
				
		update_face()


func _on_character_picker_custom_copy(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	var image_data = get_data().character
	if not image_data.is_empty():
		clipboard[clipboard_key] = image_data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)


func _on_character_picker_custom_paste(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	var image_data = clipboard.get(clipboard_key, {})
	if image_data:
		if "image_type" in clipboard[clipboard_key]:
			if clipboard[clipboard_key].image_type == 1:
				get_data().character = image_data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			else:
				if "path" in image_data:
					get_data().character.path = image_data.path
		elif "icon" in clipboard[clipboard_key]:
			var character = get_data().character
			if "path" in character:
				character.path.path = clipboard[clipboard_key].icon.get_path()
				character.path.region = clipboard[clipboard_key].region
		
		update_character()
