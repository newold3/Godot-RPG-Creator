@tool
extends CommandBaseDialog


var current_map_id: int = 0
var current_target: int = 0 # 0 Player, 1 Vehicle, 2 Event
var current_type: int = 0 # 0 Manual, 1 Use variable, 2 Swap Event Position
var type_values = {}


func _ready() -> void:
	super()
	parameter_code = 53
	
	_set_animations()
	_set_check_box_connections()
	_set_variable_name()


func _set_check_box_connections() -> void:
	var nodes = [%ManualSettingChecker, %VariableSettingChecker, %SwapEventChecker]
	var group = ButtonGroup.new()
	for i: int in nodes.size():
		var node: CheckBox = nodes[i]
		node.button_group = group
		node.toggled.connect(_on_check_box_toggled.bind(node, i))
	
	nodes[0].set_pressed(true)


func _format_text(text: String) -> String:
	var words = text.split("_")
	var formatted_words = []
	
	for word in words:
		formatted_words.append(word.capitalize())
	
	return " ".join(formatted_words)


func _set_animations() -> void:
	var node1 = %TransferExitAnimation
	node1.clear()
	
	for animation: String in TeleportTransitions.ExitAnimation.keys():
		var ani = _format_text(animation)
		node1.add_item(tr(ani))
	
	var node2 = %TransferEntryAnimation
	node2.clear()
	
	for animation: String in TeleportTransitions.EntryAnimation.keys():
		var ani = _format_text(animation)
		node2.add_item(tr(ani))


func _on_check_box_toggled(toggled_on: bool, node: CheckBox, id: int) -> void:
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)
	if toggled_on:
		current_type = id


func set_player_transfer_mode() -> void:
	%VehicleContainer.visible = false
	%EventContainer.visible = false
	%MapIDContainer.visible = true
	%EventExtraContainer.visible = false
	%DirectionContainer.visible = true
	%PlayerContainer.visible = true
	%WaitAnimationContainer.visible = false
	current_target = 0
	size.y = 0


func set_vehicle_transfer_mode() -> void:
	%VehicleContainer.visible = true
	%EventContainer.visible = false
	%MapIDContainer.visible = true
	%EventExtraContainer.visible = false
	%DirectionContainer.visible = true
	%PlayerContainer.visible = false
	%WaitAnimationContainer.visible = true
	current_target = 1
	size.y = 0


func set_event_transfer_mode() -> void:
	%VehicleContainer.visible = false
	%EventContainer.visible = true
	%MapIDContainer.visible = false
	%EventExtraContainer.visible = true
	%DirectionContainer.visible = true
	%PlayerContainer.visible = false
	%WaitAnimationContainer.visible = true
	current_target = 2
	size.y = 0


func set_events(events: Array) -> void:
	var node1 = %SwapEventButton
	node1.clear()
	var node2 = %EventOptions
	node2.clear()
	
	node1.add_item("This Event")
	node2.add_item("This Event")
	
	for event: RPGEvent in events:
		node1.add_item("%s: %s" % [event.id, event.name])
		node2.add_item("%s: %s" % [event.id, event.name])


func set_data() -> void:
	current_target = parameters[0].parameters.get("target", 0)
	current_type = parameters[0].parameters.get("type", 0)
	
	if current_target == 0:
		set_player_transfer_mode()
		var delay_transfer = parameters[0].parameters.get("delay_transfer", false)
		%DelayTransfer.set_pressed(delay_transfer)
	elif current_target == 1:
		set_vehicle_transfer_mode()
		var index = parameters[0].parameters.get("vehicle_id", 0)
		index = min(%VehicleOptions.get_item_count(), max(0, index))
		%VehicleOptions.select(index)
	elif current_target == 2:
		set_event_transfer_mode()
		
		var index = parameters[0].parameters.get("value", {}).get("swap_event_id", 0)
		if index > 0 and %SwapEventButton.get_item_count() > index:
			%SwapEventButton.select(index)
		else:
			%SwapEventButton.select(0)
		
		index = parameters[0].parameters.get("value", {}).get("event_id", 0)
		if index > 0 and %EventOptions.get_item_count() > index:
			%EventOptions.select(index)
		else:
			%EventOptions.select(0)
	
	var index = parameters[0].parameters.get("direction", 0)
	index = max(0, min(index, %DirectionButton.get_item_count()))
	%DirectionButton.select(index)
	
	var values = parameters[0].parameters.get("value", {})
		
	type_values.assigned_map_id = values.get("assigned_map_id", 0)
	if type_values.assigned_map_id == 0:
		type_values.assigned_map_id = current_map_id
	type_values.assigned_x = values.get("assigned_x", 0)
	type_values.assigned_y = values.get("assigned_y", 0)
	type_values.map_id = values.get("map_id", 1)
	type_values.x = values.get("x", 1)
	type_values.y = values.get("y", 1)
	type_values.swap_event_id = values.get("swap_event_id", 0)
	type_values.event_id = values.get("event_id", 0)
	
	if current_type == 0:
		%ManualSettingChecker.set_pressed(true)
	elif current_type == 1:
		%VariableSettingChecker.set_pressed(true)
	elif current_type == 2:
		%SwapEventChecker.set_pressed(true)

	var transfer_animation = parameters[0].parameters.get("transfer_animation", 
		{
			"exit_animation": 0,
			"exit_time": 0.5,
			"entry_animation": 0,
			"entry_time": 0.5
		}
	)
	
	var transfer_animation_id = max(0, min(transfer_animation.exit_animation, %TransferExitAnimation.get_item_count() - 1))
	%TransferExitAnimation.select(transfer_animation_id)
	%AnimationExitTime.value = transfer_animation.exit_time
	transfer_animation_id = max(0, min(transfer_animation.entry_animation, %TransferEntryAnimation.get_item_count() - 1))
	%TransferEntryAnimation.select(transfer_animation_id)
	%AnimationEntryTime.value = transfer_animation.entry_time
	
	%WaitAnimationFinished.set_pressed_no_signal(parameters[0].parameters.get("wait_animation", true))
	
	_set_map_name()
	
	_set_variable_name()


func _on_ok_button_pressed() -> void:
	var commands: Array[RPGEventCommand] = build_command_list()
	if (commands[0].parameters.type == 0 and commands[0].parameters.value.get("assigned_map_id", 0) != 0) or \
		commands[0].parameters.target == 2:
		command_changed.emit(commands)
	queue_free()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	propagate_call("apply")
	commands[-1].parameters.target = current_target
	commands[-1].parameters.type = current_type
	if current_target == 1:
		commands[-1].parameters.vehicle_id = %VehicleOptions.get_selected_id()
	commands[-1].parameters.direction = %DirectionButton.get_selected_id()
	if current_target == 0:
		commands[-1].parameters.delay_transfer = %DelayTransfer.is_pressed()
	commands[-1].parameters.value = get_value()
	commands[-1].parameters.wait_animation = %WaitAnimationFinished.is_pressed()
	commands[-1].parameters.transfer_animation = {
		"exit_animation": %TransferExitAnimation.get_selected_id(),
		"exit_time": %AnimationExitTime.value,
		"entry_animation": %TransferEntryAnimation.get_selected_id(),
		"entry_time": %AnimationEntryTime.value
	}

	return commands


func get_value() -> Dictionary:
	var value: Dictionary = {}
	if current_type == 0: # Manual Settings
		value.assigned_map_id = type_values.get("assigned_map_id", 0)
		value.assigned_x = type_values.get("assigned_x", 0)
		value.assigned_y = type_values.get("assigned_y", 0)
	elif current_type == 1: # Variable Settings
		if current_target != 2:
			value.map_id = type_values.get("map_id", 1)
		value.x = type_values.get("x", 1)
		value.y = type_values.get("y", 1)
	elif current_type == 2: # Swap For Other Event
		value.swap_event_id = %SwapEventButton.get_selected_id()
	value.event_id = %EventOptions.get_selected_id()
	
	return value


func _on_variable_setting_button_1_pressed() -> void:
	_show_variable_dialog(%VariableSettingButton1, 0)


func _on_variable_setting_button_2_pressed() -> void:
	_show_variable_dialog(%VariableSettingButton2, 1)


func _on_variable_setting_button_3_pressed() -> void:
	_show_variable_dialog(%VariableSettingButton3, 2)


func _show_variable_dialog(button: Button, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed.bind(target)
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = button
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	var current_variable_id: int
	if target == 0:
		current_variable_id = type_values.get("map_id", 1)
	elif target == 1:
		current_variable_id = type_values.get("x", 1)
	elif target == 2:
		current_variable_id = type_values.get("y", 1)
	dialog.setup(current_variable_id)


func _on_variable_changed(index: int, button: Node, target: int) -> void:
	if target == 0:
		type_values.map_id = index
	elif target == 1:
		type_values.x = index
	elif target == 2:
		type_values.y = index
	_set_variable_name()


func _set_variable_name() -> void:
	var variables = RPGSYSTEM.system.variables
	
	var index = type_values.get("map_id", 1)
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%VariableSettingButton1.text = variable_name
	
	index = type_values.get("x", 1)
	variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%VariableSettingButton2.text = variable_name
	
	index = type_values.get("y", 1)
	variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%VariableSettingButton3.text = variable_name


func _on_manual_setting_button_1_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/select_map_position_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var map_id = type_values.get("assigned_map_id", 0)
	var x = type_values.get("assigned_x", 0)
	var y = type_values.get("assigned_y", 0)
	var start_position = Vector2i(x, y)
	
	dialog.restrict_position_to_terrain.clear()
	if current_target == 1 and %VehicleOptions.get_selected_id() == 1:
		dialog.set_terrain_restrictions(PackedStringArray(["*Water"]))
	else:
		dialog.set_terrain_restrictions(PackedStringArray([]))
	
	if map_id:
		var map_path = RPGMapsInfo.get_map_by_id(map_id)
		dialog.set_start_map(map_path, start_position)
	else:
		dialog.select_initial_map()
	
	if current_target == 2:
		dialog.hide_map_list()

	dialog.cell_selected.connect(_on_manual_map_position_selected)


func _on_manual_map_position_selected(map_id: int, start_position: Vector2i) -> void:
	type_values.assigned_map_id = map_id
	type_values.assigned_x = start_position.x
	type_values.assigned_y = start_position.y
	_set_map_name()


func _set_map_name() -> void:
	var map_name: String = ""
	var map_id = type_values.get("assigned_map_id", 0)
	var x = type_values.get("assigned_x", 0)
	var y = type_values.get("assigned_y", 0)
	
	if current_type == 0:
		if map_id != 0:
			if map_id == current_map_id:
				map_name = "Current Map"
			else:
				map_name = RPGMapsInfo.map_infos.get_map_name_from_id(map_id)
		if !map_name:
			map_name = "Select a destination"
		else:
			map_name += " (%s, %s)" % [x, y]
		
	%ManualSettingButton1.text = map_name
	%ManualSettingButton1.set_disabled(false)
