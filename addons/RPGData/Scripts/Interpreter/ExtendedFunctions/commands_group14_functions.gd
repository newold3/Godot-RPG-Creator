class_name CommandsGroup14
extends CommandHandlerBase


# Command Input Actor Name (Code 98), button_id = 77
# Code 98 parameters { actor_id, max_letters }
func _command_0098() -> void:
	debug_print("Command 98 is not implemented")

	var actor_id = current_command.parameters.get("actor_id", 0)
	var max_letters = current_command.parameters.get("max_letters", 0)


# Command Show Menu Scene (Code 99), button_id = 78
# Code 99 parameters { }
func _command_0099() -> void:
	debug_print("Command 99 is not implemented")



# Command Show Save Scene (Code 100), button_id = 79
# Code 100 parameters { }
func _command_0100() -> void:
	debug_print("Command 100 is not implemented")


# Command Show Game Over Scene (Code 101), button_id = 80
# Code 101 parameters { }
func _command_0101() -> void:
	debug_print("Command 101 is not implemented")


# Command Show Title Scene (Code 102), button_ids = 81
# Code 102 parameters { }
func _command_0102() -> void:
	debug_print("Command 102 is not implemented")
