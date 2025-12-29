@tool
extends Window

var last_index = -1
var current_data: Array[RPGInvocationSequence]

signal sequence_changed(data: Array[RPGInvocationSequence])


func _ready() -> void:
	close_requested.connect(queue_free)
	%CustomTooltip.gui_input.connect(_on_tooltip_gui_input)
	%CustomTooltip2.gui_input.connect(_on_tooltip_gui_input)
	%SequenceList.disable_space_input(true)
	%PasteParameters.set_disabled(not "skill_sequence" in StaticEditorVars.CLIPBOARD)
	fill_list(0)


func _on_tooltip_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if %CommandMenu.visible:
			set_command_menu_tooltips(%CommandMenu.get_focused_item())
		elif %RightClickPopup.visible:
			set_right_click_menu_tooltips(%RightClickPopup.get_focused_item())


func set_command_menu_tooltips(index: int) -> void:
	if index == last_index: return
	last_index = index
	
	var tooltips = [
		"Displays one of the character's selectable animations",
		"Makes the character move towards the target before using the skill",
		"Displays the character's own animation without triggering any sequence",
		"Displays another animation from the database without triggering its sequence",
		"Makes the character exit the screen from the back during the animation",
		"Makes the character exit the screen from the front during the animation",
		"Makes the character exit the screen from the top during the animation",
		"Repositions the character to a specific location during the skill animation",
		"Applies a percentage of the skill's damage or healing effect at this point in the sequence. If no command is specified, damage is processed at the end of the sequence. If one or more of these commands are used, the damage percentage is processed as specified. If there's remaining damage percentage not applied at the end, it will be applied to the total. If the sum of percentages exceeds 100%, only up to 100% of the damage will be applied.",
		"Triggers the sound effect",
		"Adjusts the camera view to zoom in/out during the skill animation",
		"Wait for a specified amount of time before executing the next command in the sequence. If the previous command is an animation, this will prevent it from waiting for the animation to finish and instead will wait for the time specified in this command."
	]
	
	var tooltip_name: String = ""
	
	if index != -1 and tooltips.size() > index:
		var current_tooltip = tr(tooltips[index])
		tooltip_name = %CommandMenu.get_item_text(index)
		%CustomTooltip.tooltip_text = "[title]%s[/title]\n%s" % [tooltip_name, current_tooltip]
	else:
		%CustomTooltip.tooltip_text = ""
	
	CustomTooltipManager.replace_all_tooltips_with_custom(%CustomTooltip)
	CustomTooltipManager._show_custom_tooltip_text_for_node(%CustomTooltip)


func set_right_click_menu_tooltips(index: int) -> void:
	if index == last_index: return
	last_index = index
	
	var tooltips = [
		"Copy selected parameters into clipboard",
		"Copy selected parameters into clipboard and remove them from the list",
		"Paste the parameters saved in the clipboard on top of the selected commands",
		"",
		"Removes the selected commands from the list"
	]
	
	var tooltip_name: String = ""
	
	if index != -1 and tooltips.size() > index:
		var current_tooltip = tr(tooltips[index])
		tooltip_name = %RightClickPopup.get_item_text(index)
		%CustomTooltip2.tooltip_text = "[title]%s[/title]\n%s" % [tooltip_name, current_tooltip]
	else:
		%CustomTooltip2.tooltip_text = ""
	
	CustomTooltipManager.replace_all_tooltips_with_custom(%CustomTooltip2)
	CustomTooltipManager._show_custom_tooltip_text_for_node(%CustomTooltip2)


func set_data(data: Array[RPGInvocationSequence]) -> void:
	current_data.clear()
	for sequence: RPGInvocationSequence in data:
		current_data.append(sequence)
	
	fill_list()


func _get_formatted_text(command: RPGInvocationSequence) -> String:
	var formatted_text = ""
	var command_name = %CommandMenu.get_item_text(command.type) + ": "
	match command.type:
		0: # Show Cast Motion
			var options = [
				tr("Casting animation"), tr("Attack animation (Current weapon)"),
				tr("Attack animation (Thrust attack)"), tr("Attack animation (Slash attack)"),
				tr("Attack animation (Smash attack)"), tr("Attack animation (Islash attack)"),
				tr("Attack animation (Shoot attack)"), tr("Attack animation (Whip attack)"),
				tr("Fishing animation")
			]
			var id = command.parameters.id
			if options.size() > id:
				formatted_text = "Show Motion <%s>" % options[id]
			else:
				formatted_text = "Show Motion <?>"
		1: # Move To Target
			var seconds = command.parameters.wait_time
			var seconds_str = "Instantly" if seconds == 0 else "In %s Seconds" % seconds
			formatted_text += "Move To Target %s" % seconds_str
		2: # Show Self Animation
			formatted_text += "Show Self Animation"
		3: # Show Other Animation (No Sequence)
			formatted_text += "Show Animation: <%s: %s>" % [
				RPGSYSTEM.database.animations[command.parameters.animation_id].id,
				RPGSYSTEM.database.animations[command.parameters.animation_id].name
			] if RPGSYSTEM.database.animations.size() > command.parameters.animation_id else "⚠ Invalid Data"
		4: # Move Out Of Screen (Back)
			var seconds = command.parameters.wait_time
			var seconds_str = "Instantly" if seconds == 0 else "In %s Seconds" % seconds
			formatted_text += "Move Out Of Screen (Back) %s" % seconds_str
		5: # Move Out Of Screen (Front)
			var seconds = command.parameters.wait_time
			var seconds_str = "Instantly" if seconds == 0 else "In %s Seconds" % seconds
			formatted_text += "Move Out Of Screen (Front) %s" % seconds_str
		6: # Move Out Of Screen (Top)
			var seconds = command.parameters.wait_time
			var seconds_str = "Instantly" if seconds == 0 else "In %s Seconds" % seconds
			formatted_text += "Move Out Of Screen (Top) %s" % seconds_str
		7: # Move To Position
			var pos = command.parameters.value
			var time = command.parameters.wait_time
			var p = "s" if time != 1 else ""
			formatted_text = "Move To Screen Position %s in %s second%s" % [pos, time, p]
		8: # Damage/ Heal % Of Total Effect
			var value = command.parameters.value
			formatted_text = "Applies %s%% of the total damage or healing of this skill instantly" % value
		9: # Play Sound FX
			var path =  command.parameters.path.get_file()
			formatted_text = "Play FX: <%s>" % path
		10: # Camera Zoom
			var zoom =  command.parameters.zoom
			var duration =  command.parameters.duration
			var s = "s" if duration != 1 else ""
			formatted_text = "Change zoom to <%s> in %s second%s" % [zoom, duration, s]
		11: # Wait command
			var wait_time = command.parameters.wait_time
			var s = "s" if wait_time != 1 else ""
			formatted_text = "Wait <%s> second%s" % [wait_time, s]
	
	return formatted_text


func fill_list(selected_index: int = -1) -> void:
	%CopyParameters.set_disabled(!current_data)
	
	var node = %SequenceList
	node.clear()
	
	for command: RPGInvocationSequence in current_data:
		var command_formatted = _get_formatted_text(command)
		node.add_column([command_formatted])
	
	await node.columns_setted
	if current_data.size() > selected_index:
		node.select(selected_index)
	elif node.get_item_count() > 0:
		node.select(node.get_item_count() - 1)
	else:
		node.select(-1)


func _on_sequence_list_item_activated(index: int) -> void:
	%CommandMenu.popup()
	var pos = position + Vector2i(get_mouse_position()) - Vector2i(%CommandMenu.size.x * 0.5, 0)
	pos.x = clamp(pos.x, 10, DisplayServer.screen_get_size().x - 10 - %CommandMenu.size.x)
	pos.y = clamp(pos.y, 10, DisplayServer.screen_get_size().y - 10 - %CommandMenu.size.y)
	%CommandMenu.position = pos


func _input(event: InputEvent) -> void:
	if RPGDialogFunctions.get_current_dialog() != self:
		return
		
	if event.is_action_pressed("ui_select"):
		var index = %SequenceList.get_selected_items()[0]
		if current_data.size() > index:
			_on_command_menu_index_pressed(current_data[index].type, current_data[index])
			get_viewport().set_input_as_handled()


func _on_ok_button_pressed() -> void:
	sequence_changed.emit(current_data)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_command_menu_index_pressed(index: int, command: RPGInvocationSequence = null) -> void:
	match index:
		0: # Show Cast Motion
			_create_command_show_caster_motion(index, command)
		1: # Move To Target
			_create_command_wait(index, " seconds", command)
		2: # Show Self Animation (No Sequence)
			if not command: _create_command_self_animation(index) # This command cannot be edited
		3: # Show Other Animation (No Sequence)
			_create_command_animation(index, command)
		4: # Move Out Of Screen (Back)
			_create_command_wait(index, " seconds", command)
		5: # Move Out Of Screen (Front)
			_create_command_wait(index, " seconds", command)
		6: # Move Out Of Screen (Top)
			_create_command_wait(index, " seconds", command)
		7: # Move To Position
			_create_command_move_to_position(index, command)
		8: # Damage/ Heal % Of Total Effect
			_create_command_damage_percent(index, command)
		9: # Play Sound FX
			_create_command_play_fx(index, command)
		10: # Camera Zoom
			_create_command_change_zoom(index, command)
		11: # Camera Zoom
			_create_command_wait(index, " seconds", command)


func _create_command_show_caster_motion(type: int, command: RPGInvocationSequence = null) -> void:
	var path = "res://addons/CustomControls/Dialogs/sequence_select_animation_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	var id_selected = 0 if not command else command.parameters.id
	dialog.set_data(id_selected)
	dialog.command_selected.connect(
		func(index):
			if not command:
				var parameter = RPGInvocationSequence.new()
				parameter.type = type
				parameter.parameters.id = index
				var selected_index = %SequenceList.get_selected_items()[0]
				current_data.insert(selected_index, parameter)
				fill_list(selected_index)
			else:
				command.parameters.id = index
				fill_list(%SequenceList.get_selected_items()[0])
	)


func _create_command_wait(type: int, suffix: String, command: RPGInvocationSequence = null) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_min_max_values(0,  30, 0.01)
	dialog.set_suffix(suffix)
	match type:
		1: dialog.set_title_and_contents(tr("Time"), tr("Movement duration:"))
		4, 5, 6: dialog.set_title_and_contents(tr("Time"), tr("Move Out Of Screen Duration:"))
		11: dialog.set_title_and_contents(tr("Time"), tr("Wait Time:"))
	if command:
		dialog.set_value(command.parameters.wait_time)
		
	dialog.selected_value.connect(_on_wait_selected_value.bind(type, command))


func _on_wait_selected_value(value: float, type: int, command: RPGInvocationSequence) -> void:
	if not command:
		var parameter = RPGInvocationSequence.new()
		parameter.type = type
		parameter.parameters.wait_time = value
		var selected_index = %SequenceList.get_selected_items()[0]
		current_data.insert(selected_index, parameter)
		fill_list(selected_index)
	else:
		command.parameters.wait_time = value
		fill_list(%SequenceList.get_selected_items()[0])


func _create_command_move_to_position(type: int, command: RPGInvocationSequence = null) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_screen_position_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	if command:
		dialog.set_data(command.parameters.wait_time)
		
	dialog.position_selected.connect(_on_move_to_position_selected.bind(type, command))


func _on_move_to_position_selected(value: Vector2, wait_time: float, type: int, command: RPGInvocationSequence) -> void:
	if not command:
		var parameter = RPGInvocationSequence.new()
		parameter.type = type
		parameter.parameters.value = value
		parameter.parameters.wait_time = wait_time
		var selected_index = %SequenceList.get_selected_items()[0]
		current_data.insert(selected_index, parameter)
		fill_list(selected_index)
	else:
		command.parameters.value = value
		command.parameters.wait_time = wait_time
		fill_list(%SequenceList.get_selected_items()[0])


func _create_command_damage_percent(type: int, command: RPGInvocationSequence = null) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sequence_damage_percent_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	if command:
		dialog.set_value(command.parameters.value)
		
	dialog.selected_value.connect(_on_damage_percent_selected_value.bind(type, command))


func _on_damage_percent_selected_value(value: float, type: int, command: RPGInvocationSequence) -> void:
	if not command:
		var parameter = RPGInvocationSequence.new()
		parameter.type = type
		parameter.parameters.value = value
		var selected_index = %SequenceList.get_selected_items()[0]
		current_data.insert(selected_index, parameter)
		fill_list(selected_index)
	else:
		command.parameters.value = value
		fill_list(%SequenceList.get_selected_items()[0])


func _create_command_play_fx(type: int, command: RPGInvocationSequence = null) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.enable_random_pitch(true)
	
	var parameters: Array[RPGEventCommand] = []
	var parameter: RPGEventCommand
	if command:
		parameter = RPGEventCommand.new(0, 0,
			{
				"path": command.parameters.path,
				"volume": command.parameters.volume,
				"pitch": command.parameters.pitch,
				"pitch2": command.parameters.pitch2,
			}
		)
	else:
		parameter = RPGEventCommand.new()
		
	parameters.append(parameter)
	dialog.set_parameters(parameters)
	dialog.command_changed.connect(_on_fx_created.bind(type, command))


func _on_fx_created(commands: Array[RPGEventCommand], type: int, command: RPGInvocationSequence) -> void:
	if not command:
		var parameter = RPGInvocationSequence.new()
		parameter.type = type
		parameter.parameters = commands[0].parameters
		var selected_index = %SequenceList.get_selected_items()[0]
		current_data.insert(selected_index, parameter)
		fill_list(selected_index)
	else:
		command.parameters = commands[0].parameters
		fill_list(%SequenceList.get_selected_items()[0])


func _create_command_change_zoom(type: int, command: RPGInvocationSequence = null) -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/sequence_change_zoom_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var parameters: Array[RPGEventCommand] = []
	var parameter: RPGEventCommand
	if command:
		parameter = RPGEventCommand.new(0, 0,
			{
				"zoom": command.parameters.zoom,
				"duration": command.parameters.duration
			}
		)
	else:
		parameter = RPGEventCommand.new()
		
	parameters.append(parameter)
	dialog.set_parameters(parameters)
	dialog.command_changed.connect(_on_change_zoom.bind(type, command))


func _on_change_zoom(commands: Array[RPGEventCommand], type: int, command: RPGInvocationSequence) -> void:
	if not command:
		var parameter = RPGInvocationSequence.new()
		parameter.type = type
		parameter.parameters = commands[0].parameters
		var selected_index = %SequenceList.get_selected_items()[0]
		current_data.insert(selected_index, parameter)
		fill_list(selected_index)
	else:
		command.parameters = commands[0].parameters
		fill_list(%SequenceList.get_selected_items()[0])


func _create_command_self_animation(type: int) -> void:
	var parameter = RPGInvocationSequence.new()
	parameter.type = type
	var selected_index = %SequenceList.get_selected_items()[0]
	current_data.insert(selected_index, parameter)
	fill_list(selected_index)
	


func _create_command_animation(type: int, command: RPGInvocationSequence = null) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var database = RPGSYSTEM.database
	dialog.database = database
	var id_selected = 1 if not command else command.parameters.animation_id
	dialog.destroy_on_hide = true
	var current_data = database.animations
	var title = TranslationManager.tr("Animations")
	dialog.selected.connect(_on_animation_selected.bind(command), CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, type)


func _on_animation_selected(id: int, type: int, command: RPGInvocationSequence) -> void:
	if not command:
		var parameter = RPGInvocationSequence.new()
		parameter.type = type
		parameter.parameters.animation_id = id
		var selected_index = %SequenceList.get_selected_items()[0]
		current_data.insert(selected_index, parameter)
		fill_list(selected_index)
	else:
		command.parameters.animation_id = id
		fill_list(%SequenceList.get_selected_items()[0])


func _on_copy_parameters_pressed() -> void:
	if current_data.size() > 0:
		var items = []
		for data: RPGInvocationSequence in current_data:
			items.append(data.clone(true))
		StaticEditorVars.CLIPBOARD["skill_sequence"] = items
		%PasteParameters.set_disabled(false)


func _on_paste_parameters_pressed() -> void:
	if "skill_sequence" in StaticEditorVars.CLIPBOARD:
		current_data = []
		for data: RPGInvocationSequence in StaticEditorVars.CLIPBOARD["skill_sequence"]:
			current_data.append(data.clone(true))
		fill_list(0)


func _on_sequence_list_copy_requested(indexes: PackedInt32Array) -> void:
	if indexes.size() > 0:
		if indexes.size() == 1 and current_data.size() <= indexes[0]:
			return
		var items = []
		for id: int in indexes:
			if current_data.size() > id:
				items.append(current_data[id].clone(true))
		StaticEditorVars.CLIPBOARD["skill_sequence"] = items
		%PasteParameters.set_disabled(false)


func _on_sequence_list_delete_pressed(indexes: PackedInt32Array) -> void:
	if indexes.size() > 0:
		for i: int in range(indexes.size() - 1, -1, -1):
			var id = indexes[i]
			if current_data.size() > id:
				var data = current_data[id]
				current_data.erase(data)
		fill_list(indexes[-1])


func _on_sequence_list_cut_requested(indexes: PackedInt32Array) -> void:
	_on_sequence_list_copy_requested(indexes)
	_on_sequence_list_delete_pressed(indexes)


func _on_sequence_list_paste_requested(index: int) -> void:
	if "skill_sequence" in StaticEditorVars.CLIPBOARD:
		for data: RPGInvocationSequence in StaticEditorVars.CLIPBOARD["skill_sequence"]:
			current_data.insert(index, data.clone(true))
		await fill_list()
		var indexes: PackedInt32Array
		for i: int in range(index, index + StaticEditorVars.CLIPBOARD["skill_sequence"].size(), 1):
			indexes.append(i)
		%SequenceList.select_items(indexes)


func _on_right_click_popup_index_pressed(index: int) -> void:
	var indexes: PackedInt32Array = %SequenceList.get_selected_items()
	match index:
		0: _on_sequence_list_copy_requested(indexes)
		1: _on_sequence_list_cut_requested(indexes)
		2: _on_sequence_list_paste_requested(indexes[0] if indexes.size() > 0 else 0)
		4: _on_sequence_list_delete_pressed(indexes)


func _on_sequence_list_button_right_pressed(indexes: PackedInt32Array) -> void:
	var node = %RightClickPopup
	node.popup()
	var pos = position + Vector2i(get_mouse_position()) - Vector2i(node.size.x * 0.5, 0)
	pos.x = clamp(pos.x, 10, DisplayServer.screen_get_size().x - 10 - node.size.x)
	pos.y = clamp(pos.y, 10, DisplayServer.screen_get_size().y - 10 - node.size.y)
	node.position = pos


func _on_right_click_popup_about_to_popup() -> void:
	var indexes: PackedInt32Array = %SequenceList.get_selected_items()
	var copy_disabled = current_data.size() == 0 or (indexes.size() == 1 and current_data.size() <= indexes[0])
	var node = %RightClickPopup
	node.set_item_disabled(0, copy_disabled)
	node.set_item_disabled(1, copy_disabled)
	node.set_item_disabled(2, not "skill_sequence" in StaticEditorVars.CLIPBOARD)
	node.set_item_disabled(4, copy_disabled)
	
