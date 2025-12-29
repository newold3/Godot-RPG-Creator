@tool
extends Window

signal ok_pressed(options: RPGCharacterCreationOptions)


var options = RPGCharacterCreationOptions.new()


func _ready() -> void:
	close_requested.connect(queue_free)
	await get_tree().process_frame
	# If not checked, godot throws an error if this scene is open when opening the editor.
	if %CharacterName.is_inside_tree():
		%CharacterName.grab_focus()


func set_options(_options: RPGCharacterCreationOptions) -> void:
	options = _options
	%CharacterFolder.text = options.character_folder
	options.name = ""
	%CharacterName.text = ""
	%CheckBox22.set_pressed_no_signal(options.all)
	%CheckBox23.set_pressed(options.create_event_character)
	%CheckBox24.set_pressed(options.is_generic_lpc_event)
	%CheckBox0.set_pressed(options.create_sub_folder)
	%CheckBox1.set_pressed(options.create_character)
	%CheckBox2.set_pressed(options.create_face_preview)
	%CheckBox3.set_pressed(options.always_show_weapon)
	%CheckBox4.set_pressed(options.create_character_preview)
	%CheckBox5.set_pressed(options.inmutable)
	%CheckBox6.set_pressed(options.create_battler_preview)
	%CheckBox7.set_pressed(options.create_equipment_parts)
	%EquipmentFolder.text = options.equipment_folder
	
	var keys = ["mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back", "mainhand", "offhand", "ammo"]
	for i in keys.size():
		var checkbox_name = "%%CheckBox%s" % (8+i)
		get_node(checkbox_name).set_pressed(options.save_parts[keys[i]])


func _on_ok_button_pressed() -> void:
	if options.name.length() == 0:
		if options.create_character or options.create_face_preview or options.create_battler_preview or options.create_character_preview:
			print("invalid name")
			%CharacterName.grab_focus()
			return
	var paths: PackedStringArray = []
	var current_folder = options.character_folder if !options.create_sub_folder else options.character_folder.path_join(options.name.capitalize())
	if options.create_character:
		paths.append(current_folder.path_join(options.name) + "_data.tres")
	if options.create_face_preview:
		paths.append(current_folder.path_join(options.name) + "_face.png")
	if options.create_battler_preview:
		paths.append(current_folder.path_join(options.name) + "_battler.png")
	if options.create_character_preview:
		paths.append(current_folder.path_join(options.name) + "_character.png")
	if options.create_event_character:
		paths.append(current_folder.path_join(options.name) + "_event.png")
	var override_files: PackedStringArray = []
	for path in paths:
		if ResourceLoader.exists(path):
			override_files.append(path)
	if override_files.size() > 0:
		var text: String = ""
		if override_files.size() == 1:
			text = "This file already exists on your hard drive:\n\n"
			text += "\t[color=red]%s[/color]\n\n" % override_files[0]
			text += "Do you want to overwrite it?\n\n"
		else:
			text = "These files already exists on your hard drive:\n\n"
			var files = ""
			for path in override_files:
				if files:
					files += "\n\t[color=red]%s[/color]" % path
				else:
					files += "\t[color=red]%s[/color]" % path
			text += files + "\n\n"
			text += "do you want to overwrite them?\n\n"
		show_override_confirmation_dialog(text)
	else:
		ok_pressed.emit(options)
		queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_check_box_0_toggled(toggled_on: bool) -> void:
	options.create_sub_folder = toggled_on


func _on_check_box_1_toggled(toggled_on: bool) -> void:
	options.create_character = toggled_on


func _on_check_box_2_toggled(toggled_on: bool) -> void:
	options.create_face_preview = toggled_on


func _on_check_box_3_toggled(toggled_on: bool) -> void:
	options.always_show_weapon = toggled_on


func _on_check_box_4_toggled(toggled_on: bool) -> void:
	options.create_character_preview = toggled_on


func _on_check_box_5_toggled(toggled_on: bool) -> void:
	options.inmutable = toggled_on


func _on_check_box_6_toggled(toggled_on: bool) -> void:
	options.create_battler_preview = toggled_on


func _on_check_box_7_toggled(toggled_on: bool) -> void:
	options.create_equipment_parts = toggled_on
	%BottomOptions.visible = toggled_on
	size.y = 0


func _on_character_name_text_changed(new_text: String) -> void:
	options.name = new_text.strip_edges().replace(" ", "_")


func _on_character_folder_button_down() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.target_callable = _set_character_folder
	dialog.set_dialog_mode(1)
	dialog.hide_directory_extra_controls2()
	dialog.destroy_on_hide = true
	
	var parent = get_parent()
	if "confirm_dialog_options" in parent and parent.confirm_dialog_options is RPGCharacterCreationOptions:
		var default_path: String
		if not options.character_folder.is_empty():
			default_path = options.character_folder
		else:
			default_path = parent.confirm_dialog_options.character_folder
		dialog.navigate_to_directory(default_path)


func _set_character_folder(path: String) -> void:
	#get_parent().characters_folder = path
	options.character_folder = path
	%CharacterFolder.text = path


func _on_equipment_folder_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.target_callable = _set_equipment_folder
	dialog.set_dialog_mode(1)
	dialog.hide_directory_extra_controls2()
	dialog.destroy_on_hide = true
	
	var parent = get_parent()
	if "confirm_dialog_options" in parent and parent.confirm_dialog_options is RPGCharacterCreationOptions:
		var default_path =  parent.confirm_dialog_options.equipment_folder
		dialog.navigate_to_directory(default_path)


func _set_equipment_folder(path: String) -> void:
	options.equipment_folder = path
	%EquipmentFolder.text = path


func show_override_confirmation_dialog(text: String) -> void:
	var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_text(text)
	dialog.title = TranslationManager.tr("Override File")
	dialog.OK.connect(override_file)


func override_file() -> void:
	ok_pressed.emit(options)
	queue_free()


func _on_save_equipment_part_toggled(toggled_on: bool, key: String) -> void:
	options.save_parts[key] = toggled_on


func _on_check_box_all_toggled(toggled_on: bool) -> void:
	options.all = toggled_on
	for i in range(8, 22, 1):
		get_node("%%CheckBox%s" % i).set_pressed(toggled_on)


func _on_check_box_23_toggled(toggled_on: bool) -> void:
	options.create_event_character = toggled_on


func _on_check_box_24_toggled(toggled_on: bool) -> void:
	options.is_generic_lpc_event = toggled_on
