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
			parent.add_child(new_message)
			GameManager.message = new_message
			new_message.setup()
		
		# Update the current message configuration in the game state
		GameManager.game_state.current_message_config = config
		
		# Apply the configuration to the message system
		GameManager.message.set_message_config(config)


# Command Text Dialog (Codes 2, 3)
# Code 2 (Parent) parameters: { position, face, character_name -> { type, value } }
# Code 3 (Text Line) parameters: { line }
func _command_0002() -> void:
	debug_print("Processing command: Show Text Dialog (code 2)")
	
	# Store the starting command index and initialize variables
	var start_command_index = current_interpreter.command_index
	var current_index = current_interpreter.command_index + 1
	var lines = []
	var current_message_config = current_command.parameters.duplicate()

	# Collect all lines of text (Code 3) until a different configuration or an invalid command is encountered
	while true:
		var command = current_interpreter.get_command(current_index)
		if command:
			if command.code == 3:  # Text line command
				lines.append(command.parameters.get("line", ""))
			elif command.code == 2 and command.parameters != current_message_config:  # Different configuration
				break
			else:  # Invalid command
				break
		else:
			break
		
		current_index += 1
	
	# Adjust the interpreter to the last valid command index
	current_interpreter.go_to(current_index - 1)
	
	var is_floating = current_message_config.get("is_floating_dialog", false)
	if is_floating:
		var target = current_message_config.get("floating_target", 0)
		if target == -1 or not GameManager.current_map:
			current_message_config.anchor_node = current_interpreter.obj
		else:
			var real_target = GameManager.current_map.get_in_game_event_by_id(target)
			current_message_config.anchor_node = real_target
		
		for child in GameManager.over_message_layer.get_children():
			if child is DialogBase and child.anchor_node == current_message_config.anchor_node:
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
			
			current_message_box.floating_initialize = true
		else:
			return
	
	# If there are lines to display and the message system is available
	if lines.size() > 0 and current_message_box:
		# Determine the configuration of the text dialog and whether to keep it open
		var previous_command = current_interpreter.get_command(start_command_index - 1)
		var command_index = current_interpreter.command_index + 1
		var next_command = current_interpreter.get_command(current_index)
		var is_next_command_request_user_action = next_command and [4, 8].has(next_command.code)

		# Enable or disable waiting for user action based on the next command
		current_message_box.wait_for_user_option_selected_enabled = is_next_command_request_user_action

		# Combine all collected lines into a single text block
		var text = "\n".join(lines)

		# Set the initial configuration for the message
		current_message_box.set_initial_config(current_message_config)
		current_message_box.dialog_is_paused = false

		# Determine if the dialog is part of a multi-dialog sequence or a new dialog
		if not is_floating:
			current_message_box.is_multi_dialog = (next_command and next_command.code == 2)
			current_message_box.is_new_dialog = (start_command_index == 0) or (previous_command and not [2, 3].has(previous_command.code))
		else:
			current_message_box.is_multi_dialog = false
			current_message_box.is_new_dialog = true
		
		# Set up the text in the message system and wait for it to finish

		await current_message_box.setup_text(text)
		
		# ensure interpreter is active
		if current_interpreter:
			if not is_floating:
				_start_showing_message() # Show the message dialog and set signals
			else:
				current_message_box.set_position_over_node()
				current_message_box.visible = true
				return
			
			# Wait for all messages to finish before ending the message processing
			await current_message_box.all_messages_finished

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
	debug_print("Processing command: Show Choices Dialog (code 4)")
	
	# Get the current indentation level of the command
	var current_indent = current_command.indent
	
	# Start processing commands from the next index
	var current_index = current_interpreter.command_index + 1
	var choices: PackedStringArray = []

	# Collect all choices (Code 5) until the end of the choice block (Code 7)
	while true:
		var command = current_interpreter.get_command(current_index)
		if command:
			if command.indent == current_indent:
				if command.code == 5: # "When" branch
					choices.append(command.parameters.get("name", ""))
				elif command.code == 7: # End of choices block
					break
		else:
			break
			
		current_index += 1
	
	# Reset the index to start processing again
	current_index = current_interpreter.command_index + 1
	
	# Disable waiting for user option selection if enabled
	if GameManager.message.wait_for_user_option_selected_enabled:
		GameManager.message.wait_for_user_option_selected_enabled = false
	
	# If there are choices available, load the choice dialog scene
	if choices.size() > 0:
		var scene_path = current_command.parameters.get("scene_path", "res://Scenes/DialogTemplates/choice_scene_1.tscn")
		if ResourceLoader.exists(scene_path):
			# Initialize the selected choice ID
			interpreter.selected_choice_id = -2
			var scene = load(scene_path).instantiate()
			
			# Connect cancel and option selection signals
			scene.cancel.connect(func(): interpreter.selected_choice_id = -1)
			scene.option_selected.connect(func(id): interpreter.selected_choice_id = id)
			
			# Position the scene in the viewport
			scene.position = interpreter.get_viewport().size / 0.5
			
			# Add the scene to the options layer and set its data
			GameManager.over_message_layer.add_child(scene)
			scene.set_data(current_command.parameters, choices)
			
			# Show the options layer and wait for the user to finish
			await scene.finish

			# Handle the user's choice
			if interpreter.selected_choice_id == -1: # User canceled
				while true:
					var command = current_interpreter.get_command(current_index)
					if command:
						if command.indent == current_indent:
							if command.code == 6: # Cancel branch
								break
							elif command.code == 7: # End of choices block
								break
					else:
						break
					current_index += 1
			elif interpreter.selected_choice_id >= 0: # User selected an option
				var current_choice_id = 0
				while true:
					var command = current_interpreter.get_command(current_index)
					if command:
						if command.indent == current_indent:
							if command.code == 5: # Target "When" branch
								if current_choice_id == interpreter.selected_choice_id:
									break
								else:
									current_choice_id += 1
							elif command.code == 7: # End of choices block
								break
					else: 
						break
					current_index += 1

	# Update the interpreter to the new command index
	current_interpreter.go_to(current_index)
	
	# End the message processing
	await end_message()


# Command Input text/Number (Code 8)
# Code 8 (Parent) parameters { type, variable_id, digits, text_format }
func _command_0008() -> void:
	debug_print("Processing command: Input Number/text (code 8)")
	
	# Disable waiting for user option selection if enabled
	if GameManager.message.wait_for_user_option_selected_enabled:
		GameManager.message.wait_for_user_option_selected_enabled = false
	
	# Get the scene path from the command parameters
	var scene_path = current_command.parameters.get("scene_path", "")
	if ResourceLoader.exists(scene_path):
		# Determine the type of variable to update (game variables or text variables)
		var type = current_command.parameters.get("type", 0)
		var var_data: String
		if type == 0:
			var_data = "game_variables"
		else:
			var_data = "game_text_variables"
		
		# Get the variable ID to update
		var variable_id = current_command.parameters.get("variable_id", 1)
		
		# Load and instantiate the input scene
		var scene = load(scene_path).instantiate()
		scene.position = Vector2(100000, 100000)  # Position the scene off-screen initially
			
		# Connect the value_selected signal to update the variable
		scene.value_selected.connect(GameManager.update_data.bind(var_data, variable_id))
		
		# Add the scene to the options layer and set its data
		GameManager.over_message_layer.add_child(scene)
		scene.set_data(current_command.parameters)

		# Show the options layer and wait for the user to select a value
		GameManager.hide_cursor()
		await scene.value_selected
	
	# End the message processing
	await end_message()


# Command Select Important Item (Code 9)
# Code 9 (Parent) parameters { variable_id, item_type }
func _command_0009() -> void:
	debug_print("Processing command: Select Important Item (code 9)")


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
