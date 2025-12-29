@tool
extends Window


var current_movement_route: RPGMovementRoute
var current_event: RPGEvent
var is_player_enabled: bool = false
var busy: bool

var backup_options_state = {"loop": false, "skip": true}


signal apply(route: RPGMovementRoute)


func _ready() -> void:
	close_requested.connect(_on_cancel_button_pressed)
	set_connections()


func set_connections() -> void:
	for button in %MovementCommandButtonContainer.get_children():
		button.pressed.connect(_on_button_pressed.bind(int(str(button.name))))
	
	var extra_button = %Button46
	extra_button.pressed.connect(_on_button_pressed.bind(int(str(extra_button.name))))


func set_current_page(current_page: RPGEventPage) -> void:
	current_movement_route = current_page.movement_route.clone()
	fill_movement_route_list(0)
	backup_options_state.loop = current_movement_route.repeat
	backup_options_state.skip = current_movement_route.skippable
	%RouteOption1.set_pressed_no_signal(current_movement_route.repeat)
	%RouteOption2.set_pressed_no_signal(current_movement_route.skippable)
	%RouteOption3.set_pressed(current_movement_route.wait)
	var node = %Target
	for i in node.get_item_count():
		var real_index = node.get_item_metadata(i)
		if real_index == current_movement_route.target:
			node.select(i)
			break
	


func set_targets(events: Array, append_player: bool = true) -> void:
	var node = %Target
	node.clear()
	
	
	if append_player:
		node.add_item("Player")
		node.set_item_metadata(-1, -1)
		is_player_enabled = true
	else:
		is_player_enabled = false
	
	if current_event:
		node.add_item("This Event")
		node.set_item_metadata(-1, 0)
	
	var id = 0 if not current_event else current_event.id
	for event: RPGEvent in events:
		if event.name:
			node.add_item(event.name)
		else:
			node.add_item("Event #%s" % event.id)
		node.set_item_metadata(-1, event.id)
	
	if node.get_item_count() > 0:
		node.select(0)
		for i in node.get_item_count():
			var real_index = node.get_item_metadata(i)
			if real_index == current_movement_route.target:
				node.select(i)
				break
	
	node.set_disabled(false)


func fill_movement_route_list(selected_index: int) -> void:
	var node = %CommandList
	node.clear()
	
	for command : RPGMovementCommand in current_movement_route.list:
		var column := []
		match command.code:
			# Column 1
			1: # Move Down
				column.append("Move Down")
			4: # Move Left
				column.append("Move Left")
			7: # Move Right
				column.append("Move Right")
			10: # Move Up
				column.append("Move Up")
			13: # Move Bottom Left
				column.append("Move Southwest")
			16: # Move Bottom Right
				column.append("Move Southeast")
			19: # Move Top Left
				column.append("Move Northwest")
			22: # Move Top Right
				column.append("Move Northeast")
			25: # Random Movement
				column.append("Random Movement")
			28: # Move To The Player
				column.append("Move To The Player")
			31: # Move Away From The Player
				column.append("Move Away From The Player")
			34: # Step Forward
				column.append("Step Ahead")
			37: # Take A Step Back
				column.append("Step Backward")
			40: # Jump
				column.append("Jump to %s" % command.parameters[0])
			43: # Wait
				column.append("Wait %s Seconds" % command.parameters[0])
			46: # Change Z-Index
				column.append("Z-Index =  %s" % command.parameters[0])
			# Column 2
			2: # Look Down
				column.append("Look Down")
			5: # Look Left
				column.append("look Left")
			8: # Look Right
				column.append("Look Right")
			11: # Look Up
				column.append("Look Up")
			14: # Turn 90º Left
				column.append("Turn 90º Left")
			17: # Turn 90º Right
				column.append("Turn 90º Right")
			20: # Turn 180º
				column.append("Turn 180º")
			23: # Turn 90º Random
				column.append("Turn 90º Random")
			26: # Look Random
				column.append("Look Random")
			29: # Look Player
				column.append("Look Player")
			32: # Look Opposite Player
				column.append("Look Opposite Player")
			35: # Switch ON
				column.append("Switch ON: %s" % get_switch_name(command.parameters[0]))
			38: # Switch OFF
				column.append("Switch OFF: %s" % get_switch_name(command.parameters[0]))
			41: # Change Speed
				column.append("Change Speed To %s" % command.parameters[0])
			44: # Change Delay
				column.append("Delay Between Motion %s" % command.parameters[0])
			
			# Column 3
			3: # Walking Animation ON
				column.append("Walking Animation ON")
			6: # Walking Animation OFF
				column.append("Walking Animation OFF")
			9: # Idle Animation ON
				column.append("Idle Animation ON")
			12: # Idle Animation OFF
				column.append("Idle Animation OFF")
			15: # Fix Direction ON
				column.append("Fix Direction ON")
			18: # Fix Direction OFF
				column.append("Fix Direction OFF")
			21: # Passable ON
				column.append("Walk Through ON")
			24: # Passable OFF
				column.append("Walk Through OFF")
			27: # Invisible ON
				column.append("Invisible ON")
			30: # Invisible OFF
				column.append("Invisible OFF")
			33: # Change Graphic
				column.append("Change Graphic To %s" % command.parameters[0].get_file().replace("." + command.parameters[0].get_extension(), ""))
			36: # Change Opacity
				column.append("Change Opacity To %s" % command.parameters[0])
			39: # Change Blend Mode
				var blend_modes = ["Mix", "Add", "Subtract", "Multiply", "Premult Alpha"]
				column.append("Change Blend To %s" % blend_modes[command.parameters[0]])
			42: # Play SE
				column.append("Play SE %s" % command.parameters[0].get_file())
			45: # Script
				column.append("Script: %s" % command.parameters[0])
		if column:
			node.add_column(column)
	
	node.add_column(["↪️"])
	
	await node.columns_setted
	
	if node.get_item_list().get_item_count() > selected_index and selected_index >= 0:
		node.select(selected_index)
	else:
		node.select(0)
		node.item_selected.emit(0)


func get_switch_name(switch_id: int) -> String:
	var switch_name = str(switch_id).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
	
	return switch_name


func _on_button_pressed(button_id: int) -> void:
	var result: bool = true
	var command = RPGMovementCommand.new(button_id)

	match button_id:
		# Column 1
		1: # Move Down
			pass
		4: # Move Left
			pass
		7: # Move Right
			pass
		10: # Move Up
			pass
		13: # Move Bottom Left
			pass
		16: # Move Bottom Right
			pass
		19: # Move Top Left
			pass
		22: # Move Top Right
			pass
		25: # Random Movement
			pass
		28: # Move To The Player
			pass
		31: # Move Away From The Player
			pass
		34: # Step Forward
			pass
		37: # Take A Step Back
			pass
		40: # Jump
			result = await open_jump_dialog(command)
		43: # Wait
			result = await open_wait_dialog(command)
		46: # Change Z-index
			result = await open_get_number(command, "Change Z-Index", -255, 255, 1)
			
		# Column 2
		2: # Look Down
			pass
		5: # Look Left
			pass
		8: # Look Right
			pass
		11: # Look Up
			pass
		14: # Turn 90º Left
			pass
		17: # Turn 90º Right
			pass
		20: # Turn 180º
			pass
		23: # turn 90º Random
			pass
		26: # Look Random
			pass
		29: # Look Player
			pass
		32: # Look Opposite Player
			pass
		35: # Switch ON
			result = await open_get_switch_dialog(command)
		38: # Switch OFF
			result = await open_get_switch_dialog(command)
		41: # Change Speed
			result = await open_get_number(command, "Speed", 30, 1000, 1)
		44: # Change Delay
			result = await open_get_number(command, "Movement Delay", 0, 1000, 0.01)
		
		# Column 3
		3: # Walking Animation ON
			pass
		6: # Walking Animation OFF
			pass
		9: # Idle Animation ON
			pass
		12: # Idle Animation OFF
			pass
		15: # Fix Direction ON
			pass
		18: # Fix Direction OFF
			pass
		21: # Passable ON
			pass
		24: # Passable OFF
			pass
		27: # Invisible ON
			pass
		30: # Invisible OFF
			pass
		33: # Change Graphic
			result = await open_change_graphic_dialog(command)
		36: # Change Opacity
			result = await open_get_number(command, "Opacity", 0, 1.0, 0.01)
		39: # Change Blend Mode
			result = await open_select_blend_dialog(command)
		42: # Play SE
			result = await open_select_se_dialog(command)
		45: # Script
			result = await open_script_dialog(command)
	
	
	if result:
		var itemlist: ItemList = %CommandList.get_item_list()
		var item_selected = itemlist.get_selected_items()
		var index
		if item_selected:
			index = item_selected[0]
			current_movement_route.list.insert(index, command)
		else:
			current_movement_route.list.append(command)
			index = itemlist.get_item_count() - 1
			
		fill_movement_route_list(index + 1)


func open_wait_dialog(command: RPGMovementCommand, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/movement_wait_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_command(command, updated)
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func open_jump_dialog(command: RPGMovementCommand, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/movement_jump_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_command(command, updated)
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func open_get_switch_dialog(command: RPGMovementCommand, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 1
	dialog.selected.connect(
		func(id: int, _target):
			command.parameters.clear()
			command.parameters.append(id)
	)
	dialog.setup(1 if !updated else command.parameters[0])
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func open_get_number(command: RPGMovementCommand, dialog_title: String, min_value: float, max_value: float, step: float, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = dialog_title
	dialog.set_min_max_values(min_value, max_value, step)
	
	if updated:
		dialog.set_value(command.parameters[0])
	
	dialog.selected_value.connect(
		func(value: float):
			command.parameters.clear()
			command.parameters.append(value)
	)
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func open_select_blend_dialog(command: RPGMovementCommand, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/select_blend_mode_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_command(command, updated)
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func open_select_se_dialog(command: RPGMovementCommand, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var commands: Array[RPGEventCommand] = []
	var other_command: RPGEventCommand
	if updated:
		other_command = RPGEventCommand.new(0, 0, {
			"path": command.parameters[0],
			"volume": command.parameters[1],
			"pitch": command.parameters[2],
			"pitch2": command.parameters[3]}
		)
	else:
		other_command = RPGEventCommand.new(0, 0, {"path": "", "volume": 0.0, "pitch": 1.0, "pitch2": 1.0})

	commands.append(other_command)
	dialog.set_parameters(commands)
	dialog.set_data()
	
	dialog.command_changed.connect(
		func(commands: Array[RPGEventCommand]):
			var c = commands[0].parameters
			command.parameters.clear()
			command.parameters.append(c.path)
			command.parameters.append(c.volume)
			command.parameters.append(c.pitch)
			command.parameters.append(c.pitch2)
	)
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func open_script_dialog(command: RPGMovementCommand, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/script_text_editor.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.text_changed.connect(
		func(text: String):
			command.parameters.clear()
			command.parameters.append(text)
	)
	dialog.set_text("" if !updated else command.parameters[0])
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func open_change_graphic_dialog(command: RPGMovementCommand, updated: bool = false) -> bool:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = func(path_selected: String):
		command.parameters.clear()
		command.parameters.append(path_selected)
		
	var file_path = "" if (not command or command.parameters.size() == 0) else command.parameters[0]
	dialog.set_file_selected(file_path)
	dialog.set_dialog_mode(0)
	
	if not is_player_enabled or (is_player_enabled and current_movement_route.target != 0):
		dialog.fill_mix_files(["events"])
	else:
		dialog.fill_mix_files(["characters"])
	
	
	await dialog.tree_exited
	
	return command.parameters.size() != 0


func _on_ok_button_pressed() -> void:
	apply.emit(current_movement_route)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_command_list_item_activated(index: int) -> void:
	var real_index = index
	if current_movement_route.list.size() <= real_index:
		return
		
	var command: RPGMovementCommand = current_movement_route.list[real_index]

	var editable_codes = [40, 43, 35, 38, 41, 44, 33, 36, 39, 42, 45, 46]
	if command.code in editable_codes:
		var result = false
		
		match command.code:
			40: # Jump
				result = await open_jump_dialog(command, true)
			43: # Wait
				result = await open_wait_dialog(command, true)
			35: # Switch ON
				result = await open_get_switch_dialog(command, true)
			38: # Switch OFF
				result = await open_get_switch_dialog(command, true)
			41: # Change Speed
				result = await open_get_number(command, "Speed", 30, 1000, 1, true)
			44: # Change Frequency / Delay
				result = await open_get_number(command, "Frequency", 0, 1000, 0.01, true)
			33: # Change Graphic
				result = await open_change_graphic_dialog(command, true)
			36: # Change Opacity
				result = await open_get_number(command, "Opacity", 0, 1.0, 0.01, true)
			39: # Change Blend Mode
				result = await open_select_blend_dialog(command, true)
			42: # Play SE
				result = await open_select_se_dialog(command, true)
			45: # Script
				result = await open_script_dialog(command, true)
			46: # Change Z-Index
				result = await open_get_number(command, "Change Z-Index", -255, 255, 1, true)
		
		if result:
			fill_movement_route_list(real_index)


func _on_route_option_1_toggled(toggled_on: bool) -> void:
	current_movement_route.repeat = toggled_on
	if !busy:
		backup_options_state.loop = toggled_on


func _on_route_option_2_toggled(toggled_on: bool) -> void:
	current_movement_route.skippable = toggled_on
	if !busy:
		backup_options_state.skip = toggled_on


func _on_route_option_3_toggled(toggled_on: bool) -> void:
	busy = false
	current_movement_route.wait = toggled_on
	if toggled_on:
		%RouteOption1.set_pressed_no_signal(false)
		%RouteOption2.set_pressed_no_signal(true)
		current_movement_route.repeat = false
		current_movement_route.skippable = true
		%RouteOption1.set_disabled(true)
		%RouteOption2.set_disabled(true)
	else:
		%RouteOption1.set_pressed_no_signal(backup_options_state.loop)
		%RouteOption2.set_pressed_no_signal(backup_options_state.skip)
		current_movement_route.repeat = backup_options_state.loop
		current_movement_route.skippable = backup_options_state.skip
		%RouteOption1.set_disabled(false)
		%RouteOption2.set_disabled(false)
	busy = false


func _on_target_item_selected(index: int) -> void:
	var real_index = %Target.get_item_metadata(index)
	current_movement_route.target = real_index
	remove_invalid_codes()


func remove_invalid_codes() -> void:
	var erase_list = []
	for command: RPGMovementCommand in current_movement_route.list:
		if command.code == 33:
			var scene_path = command.parameters[0]
			if is_player_enabled and current_movement_route.target == 0:
				if not scene_path in FileCache.cache["characters"]:
					erase_list.append(command)
			elif not is_player_enabled or (is_player_enabled and current_movement_route.target != 0):
				if not scene_path in FileCache.cache["events"]:
					erase_list.append(command)
	
	if erase_list.size() > 0:
		var indexes = %CommandList.get_selected_items()
		var current_index = 0 if indexes.is_empty() else indexes[0]
		for command: RPGMovementCommand in erase_list:
			current_movement_route.list.erase(command)
		current_index = max(-1, min(current_index, %CommandList.get_item_count() - 1))
		fill_movement_route_list(current_index)


func _on_command_list_copy_requested(indexes: PackedInt32Array) -> void:
	var commands: Array[RPGMovementCommand] = []

	for index in indexes:
		if current_movement_route.list.size() > index:
			commands.append(current_movement_route.list[index].clone(true))
	
	StaticEditorVars.CLIPBOARD["movement_route"] = commands


func _on_command_list_cut_requested(indexes: PackedInt32Array) -> void:
	_on_command_list_copy_requested(indexes)
	_on_command_list_delete_pressed(indexes)


func _on_command_list_delete_pressed(indexes: PackedInt32Array) -> void:
	for i in range(indexes.size() - 1, -1, -1):
		if current_movement_route.list.size() > indexes[i]:
			current_movement_route.list.remove_at(indexes[i])
	
	fill_movement_route_list(%CommandList.get_selected_items()[0])


func _insert_validated_commands(commands: Array[RPGMovementCommand], index: int) -> void:
	var inserted = 0
	for i in range(commands.size() - 1, -1, -1):
		var command = commands[i]
		if command.code == 33:
			var scene_path = command.parameters[0]
			if is_player_enabled and current_movement_route.target == 0 and scene_path in FileCache.cache["characters"]:
				current_movement_route.list.insert(index, command.clone(true))
				inserted += 1
			elif (not is_player_enabled or current_movement_route.target != 0) and scene_path in FileCache.cache["events"]:
				current_movement_route.list.insert(index, command.clone(true))
				inserted += 1
		else:
			current_movement_route.list.insert(index, command.clone(true))
			inserted += 1
	
	await fill_movement_route_list(index)
		
	for i in range(index, index + inserted, 1):
		%CommandList.select(i, false)


func _on_command_list_paste_requested(index: int) -> void:
	var commands_pasted = 0
	index = min(index, current_movement_route.list.size())
	if "movement_route" in StaticEditorVars.CLIPBOARD:
		_insert_validated_commands(StaticEditorVars.CLIPBOARD["movement_route"], index)


func _on_command_list_duplicate_requested(indexes: PackedInt32Array) -> void:
	var commands: Array[RPGMovementCommand] = []

	for index in indexes:
		if current_movement_route.list.size() > index:
			commands.append(current_movement_route.list[index].clone(true))
	
	if commands:
		var index = indexes[-1] + 1
		_insert_validated_commands(commands, index)


func disable_await() -> void:
	%RouteOption3.set_pressed(false)
	%RouteOption3.set_disabled(true)
