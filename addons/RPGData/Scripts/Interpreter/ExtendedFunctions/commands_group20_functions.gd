class_name CommandsGroup20
extends CommandHandlerBase



# Execute Script Command (Code 5000), button_ids = 106
# Code 5000 parameters { script }
func _command_5000() -> void:
	debug_print("Processing command: Execute Script Command (code 5000)")
	
	var script_contents = current_command.parameters.get("script", "")
	var result = await interpreter.code_eval.execute(script_contents)


# Visual Separator Command (Code 9999), button_ids = "none"
# Code 9999 parameters { background_color, text, text_color }
func _command_9999() -> void:
	debug_print("Processing command: Execute Script Command (code 9999)")
	
	# The sole purpose of this command is to serve as a visual representation
	# in the command editor, acting as a separator between command blocks.
