class_name CommandsGroup1
extends CommandHandlerBase


const DIALOG_BASE = preload("res://Scenes/DialogTemplates/base_dialog.tscn")


# Show the message dialog and set signals
# If this command is the last one in the interpreter, it will close the message dialog
# and immediately disables busy to return control to the player without waiting for the dialog closing animation
func _start_showing_message() -> void:
	# Update the interpreter state and visibility
	var current_index = current_interpreter.command_index + 1
	
	interpreter.showing_message = true
	GameManager.message_container.visible = true
	if current_index >= current_interpreter.commands.size() - 1:
		var is_still_busy = interpreter.interpreters.any(
			func(interpreter):
				if interpreter == current_interpreter: return false
				return not interpreter.is_parallel() and interpreter.busy
		)
		if not is_still_busy:
			GameManager.message.closing.connect(
				func():
					interpreter.showing_message = false
					interpreter.busy = false
			, CONNECT_ONE_SHOT)


# Command Config Text Dialog (Code 1)
# Code 1 (Parent) parameters {
# 	scene_path, max_width, max_lines, character_delay, dot_delay comma_delay,
# 	can_skip, skip_mode, skip_speed, start_animation,
# 	end_animation, text_transition, fx_path, fx_volume, fx_pitch_min, fx_pitch_max }
func _command_0001() -> void:
	debug_print("Processing command: Set Config Text Dialog (code 1)")
	# If the message system is available, configure it with the current command parameters
	if GameManager.message:
		# Retrieve the configuration parameters from the current command
		var config = current_command.parameters
		var scene_path = str(config.get("scene_path"))
		
		if scene_path != GameManager.message.get_scene_file_path() and ResourceLoader.exists(scene_path):
			var parent = GameManager.message.get_parent()
			parent.remove_child(GameManager.message)
			GameManager.message.queue_free()
			var new_message = load(scene_path).instantiate()
			var new_parent = GameManager.get_fixed_message_container() if new_message.fixed_position else GameManager.get_message_container()
			new_parent.add_child(new_message)
			GameManager.message = new_message
			new_message.all_messages_finished.connect(GameInterpreter.set.bind("showing_message", false), CONNECT_DEFERRED)
			new_message.setup()
		
		# Update the current message configuration in the game state
		GameManager.game_state.current_message_config = config
		
		# Apply the configuration to the message system
		GameManager.message.set_message_config(config)


## Gets the next valid command, skipping structural and ignored commands.
func _get_next_dialog_command(from_index: int):
	var look_idx = from_index
	while true:
		var cmd = current_interpreter.get_command(look_idx)
		if not cmd:
			return null
		
		if cmd.get("ignore_command") or cmd.code == 0:
			look_idx += 1
			continue
		
		if cmd.code in [5, 6]:
			var target_indent = cmd.indent
			while true:
				look_idx += 1
				var skip_cmd = current_interpreter.get_command(look_idx)
				if not skip_cmd:
					break
				if skip_cmd.code == 7 and skip_cmd.indent == target_indent:
					break
			look_idx += 1
			continue
		
		if cmd.code == 7:
			look_idx += 1
			continue
		
		return cmd


## Gets the previous valid dialog command, skipping structural, ignored, and input commands.
func _get_previous_dialog_command(from_index: int):
	var look_idx = from_index
	while look_idx >= 0:
		var cmd = current_interpreter.get_command(look_idx)
		if not cmd:
			return null
		
		if cmd.get("ignore_command") or cmd.code == 0:
			look_idx -= 1
			continue
		
		if cmd.code in [5, 6, 7]:
			var target_indent = cmd.indent
			while look_idx >= 0:
				look_idx -= 1
				var skip_cmd = current_interpreter.get_command(look_idx)
				if not skip_cmd:
					break
				if skip_cmd.code == 4 and skip_cmd.indent == target_indent:
					break
			continue
		
		if cmd.code in [4, 8, 9]:
			look_idx -= 1
			continue
		
		return cmd


func _update_dialog_state_for_next_command(current_idx: int) -> bool:
	var next_cmd = _get_next_dialog_command(current_idx)
	var is_dialog = next_cmd != null and next_cmd.code in [2, 3]
	var is_input = next_cmd != null and next_cmd.code in [4, 8, 9]
	
	if GameManager.message:
		GameManager.message.set("has_next_dialog", is_dialog)
		GameManager.message.wait_for_user_option_selected_enabled = is_input
	
	return is_dialog or is_input


# Command Text Dialog (Codes 2, 3)
# Code 2 (Parent) parameters: { position, face, character_name -> { type, value } }
# Code 3 (Text Line) parameters: { line }
func _command_0002() -> void:
	var start_command_index = current_interpreter.command_index
	var current_index = current_interpreter.command_index + 1
	var lines = []
	var current_message_config = current_command.parameters.duplicate()

	while true:
		var command = current_interpreter.get_command(current_index)
		if command:
			if command.get("ignore_command"):
				current_index += 1
				continue
			if command.code == 3:
				lines.append(command.parameters.get("line", ""))
			elif command.code == 2 and command.parameters != current_message_config:
				break
			else:
				break
		else:
			break
		current_index += 1
	
	current_interpreter.go_to(current_index - 1)
	
	var is_floating = current_message_config.get("is_floating_dialog", false)
	if is_floating:
		var target = current_message_config.get("floating_target", 0)
		if not GameManager.current_map:
			current_message_config.anchor_node = null
		elif target == -1 or target == 0:
			if "current_event" in current_interpreter.obj:
				current_message_config.anchor_node = GameManager.current_map.get_in_game_event_by_uniq_id(current_interpreter.obj.current_event._uniq_id, true)
			else:
				current_message_config.anchor_node = current_interpreter.obj
		else:
			var real_target = GameManager.current_map.get_in_game_event_by_uniq_id(target, true)
			current_message_config.anchor_node = real_target

		var target_event = current_message_config.anchor_node if not "lpc_event" in current_message_config.anchor_node else current_message_config.anchor_node.lpc_event
		for child in GameManager.over_message_layer.get_children():
			if child is DialogBase and (child.anchor_node == current_message_config.anchor_node or child.anchor_node == target_event):
				child.queue_free()
			
	var current_message_box
	if not is_floating:
		current_message_box = GameManager.message
	else:
		if GameManager.over_message_layer:
			var message_config = GameManager.game_state.current_message_config
			var scene_path = str(message_config.get("scene_path"))
			if scene_path != DIALOG_BASE.get_path() and ResourceLoader.exists(scene_path):
				current_message_box = load(scene_path).instantiate()
			else:
				current_message_box = DIALOG_BASE.instantiate()
			current_message_box.visible = false
			current_message_box.all_messages_finished.connect(current_message_box.queue_free)
			GameManager.over_message_layer.add_child(current_message_box)
			current_message_box.setup()
			current_message_box.set_message_config(message_config)
			current_message_box.propagate_call("set", ["size", Vector2.ZERO])
			current_message_box.floating_initialize = true
		else:
			return
	
	if lines.size() > 0 and current_message_box:
		var is_multi = false
		var prev_idx = start_command_index - 1
		
		while prev_idx >= 0:
			var cmd = current_interpreter.get_command(prev_idx)
			if not cmd:
				break
				
			if cmd.get("ignore_command") or cmd.code == 0:
				prev_idx -= 1
				continue
				
			if cmd.code in [5, 6, 7]:
				var target_indent = cmd.indent
				while prev_idx >= 0:
					prev_idx -= 1
					var skip_cmd = current_interpreter.get_command(prev_idx)
					if not skip_cmd:
						break
					if skip_cmd.code == 4 and skip_cmd.indent == target_indent:
						break
				continue
				
			if cmd.code in [4, 8, 9]:
				break
				
			if cmd.code == 3:
				prev_idx -= 1
				continue
				
			if cmd.code == 2:
				var prev_is_floating = cmd.parameters.get("is_floating_dialog", false)
				if prev_is_floating == is_floating:
					if is_floating:
						if cmd.parameters.get("floating_target", 0) == current_message_config.get("floating_target", 0):
							is_multi = true
							break
					else:
						is_multi = true
						break
				prev_idx -= 1
				continue
				
			break
		
		var next_command = _get_next_dialog_command(current_index)

		var text = "\n".join(lines)
		current_message_box.set_initial_config(current_message_config)
		current_message_box.dialog_is_paused = false

		if not is_floating:
			current_message_box.is_multi_dialog = is_multi
			current_message_box.is_new_dialog = not is_multi
		else:
			current_message_box.is_multi_dialog = false
			current_message_box.is_new_dialog = true
		
		var is_next_command_request_user_action = next_command != null and next_command.code in [4, 8, 9]
		var has_next_dialog = next_command != null and next_command.code == 2
		
		current_message_box.wait_for_user_option_selected_enabled = is_next_command_request_user_action
		current_message_box.set("has_next_dialog", has_next_dialog)
		
		await current_message_box.setup_text(tr(text))
		
		current_message_box.wait_for_user_option_selected_enabled = is_next_command_request_user_action
		current_message_box.set("has_next_dialog", has_next_dialog)
		
		if current_interpreter:
			if not is_floating:
				_start_showing_message()
			else:
				current_message_box.set_position_over_node()
				current_message_box.visible = true
				return
			
			await current_message_box.all_messages_finished

		if not has_next_dialog and not is_next_command_request_user_action:
			await end_message()


# Command Resume Dialog (Code 95)
# Code 95 (Parent) parameters: {  }
func _command_0095() -> void:
	debug_print("Processing command: Resume text Dialog (code 95)")
	
	# Check if the dialog is currently paused
	if GameManager.message.dialog_is_paused:
		# Resume the paused dialog
		GameManager.message.resume()
		_start_showing_message() # Show the message dialog and set signals
		
		# Wait for all messages to finish before proceeding
		await GameManager.message.all_messages_finished
	
		# End the message processing
		await end_message()


# Command Show Choices (Codes 4, 5, 6, 7)
# Code 4 (Parent) parameters {
#	scene_path, cancel, default, max_choices, next, position, previous, move_fx, select_fx, cancel_fx }
#   move_fx, select_fx, cancel_fx  = { path, volume, pitch }
# Code 5 (When) parameters { name }
# Code 6 (Cancel) parameters { }
# Code 7 (End) parameters { }
func _command_0004() -> void:
	var current_indent = current_command.indent
	var current_index = current_interpreter.command_index + 1
	var choices: PackedStringArray = []
	while true:
		var command = current_interpreter.get_command(current_index)
		if command:
			if command.indent == current_indent:
				if command.code == 5:
					choices.append(command.parameters.get("name", ""))
				elif command.code == 7:
					break
		else:
			break
		current_index += 1
	
	current_index = current_interpreter.command_index + 1
	
	if choices.size() > 0:
		var scene_path = current_command.parameters.get("scene_path", "res://Scenes/DialogTemplates/choice_scene_1.tscn")
		if ResourceLoader.exists(scene_path):
			interpreter.selected_choice_id = -2
			var scene = load(scene_path).instantiate()
			scene.cancel.connect(func(): interpreter.selected_choice_id = -1)
			scene.option_selected.connect(func(id): interpreter.selected_choice_id = id)
			scene.position = interpreter.get_viewport().size / 0.5
			GameManager.over_message_layer.add_child(scene)
			scene.set_data(current_command.parameters, choices)
			await scene.finish
			
			if interpreter.selected_choice_id == -1:
				while true:
					var command = current_interpreter.get_command(current_index)
					if command:
						if command.indent == current_indent:
							if command.code == 6 or command.code == 7:
								break
					else:
						break
					current_index += 1
			elif interpreter.selected_choice_id >= 0:
				var current_choice_id = 0
				while true:
					var command = current_interpreter.get_command(current_index)
					if command:
						if command.indent == current_indent:
							if command.code == 5:
								if current_choice_id == interpreter.selected_choice_id:
									break
								else:
									current_choice_id += 1
							elif command.code == 7:
								break
					else:
						break
					current_index += 1
	
	current_interpreter.go_to(current_index)
	
	var will_continue = _update_dialog_state_for_next_command(current_index + 1)
	
	if not will_continue:
		if "showing_message" in self:
			self.showing_message = false
		elif "showing_message" in interpreter:
			interpreter.showing_message = false
		GameManager.message.waiting_for_input = false
		await interpreter.end_message()
	else:
		GameManager.message.waiting_for_input = false


# Command Input text/Number (Code 8)
# Code 8 (Parent) parameters { type, variable_id, digits, text_format }
func _command_0008() -> void:
	if GameManager.message.wait_for_user_option_selected_enabled:
		GameManager.message.wait_for_user_option_selected_enabled = false
	
	var scene_path = current_command.parameters.get("scene_path", "")
	if ResourceLoader.exists(scene_path):
		var type = current_command.parameters.get("type", 0)
		var var_data: String
		if type == 0:
			var_data = "game_variables"
		else:
			var_data = "game_text_variables"
		
		var variable_id = current_command.parameters.get("variable_id", 1)
		var scene = load(scene_path).instantiate()
		scene.position = Vector2(100000, 100000)
		scene.value_selected.connect(GameManager.update_data.bind(var_data, variable_id))
		GameManager.over_message_layer.add_child(scene)
		scene.set_data(current_command.parameters)
		GameManager.hide_cursor()
		await scene.value_selected
	
	var next_cmd = _get_next_dialog_command(current_interpreter.command_index + 1)
	var next_is_dialog = next_cmd != null and next_cmd.code in [2, 4, 8, 9]
	
	if not next_is_dialog:
		await end_message()


# Command Select Important Item (Code 9)
# Code 9 (Parent) parameters { variable_id, item_type }
func _command_0009() -> void:
	var next_cmd = _get_next_dialog_command(current_interpreter.command_index + 1)
	var next_is_dialog = next_cmd != null and next_cmd.code in [2, 4, 8, 9]
	
	if not next_is_dialog:
		if current_interpreter.has_method("end_message"):
			await current_interpreter.end_message()
		else:
			await end_message()


# Comand Scrolling Dialog (Codes 10, 11)
# Code 10 (Parent) parameters: { scroll_speed, scroll_direction, scroll_scene, enable_fast_forward }
# Code 11 (Scrolling Text Line) parameters: { line }
func _command_0010() -> void:
	debug_print("Command 10 is not implemented")


# Command Instant Text (Codes 34, 35)
# Code 34 (Line 1) parameters: { first_line }
# Code 35 (All other lines) parameters: { line }
func _command_0034() -> void:
	debug_print("Command 34 is not implemented")
