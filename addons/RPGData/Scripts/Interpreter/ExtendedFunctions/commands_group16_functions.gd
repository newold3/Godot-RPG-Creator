class_name CommandsGroup16
extends CommandHandlerBase


# Command Change Battle BGM (Code 110), button_id = 86
# Code 110 parameters { path, volume, pitch, fade_in }
func _command_0110() -> void:
	debug_print("Command 110 is not implemented")

	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 1.0)
	var pitch = current_command.parameters.get("pitch", 1.0)
	var fade_in = current_command.parameters.get("fade_in", 0.0)


# Command Change Victory ME (Code 111), button_id = 87
# Code 111 parameters { path, volume, pitch, fade_in }
func _command_0111() -> void:
	debug_print("Command 111 is not implemented")

	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 1.0)
	var pitch = current_command.parameters.get("pitch", 1.0)
	var fade_in = current_command.parameters.get("fade_in", 0.0)




# Command Change Defeat ME (Code 112), button_id = 88
# Code 112 parameters { path, volume, pitch, fade_in }
func _command_0112() -> void:
	debug_print("Command 112 is not implemented")

	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 1.0)
	var pitch = current_command.parameters.get("pitch", 1.0)
	var fade_in = current_command.parameters.get("fade_in", 0.0)


# Command Change Vehicle BGM (Code 121), button_id = 110
# Code 121 parameters { vehicle_id, path, volume, pitch, fade_in }
func _command_0121() -> void:
	debug_print("Command 121 is not implemented")

	var vehicle_id = current_command.parameters.get("vehicle_id", 0)
	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 1.0)
	var pitch = current_command.parameters.get("pitch", 1.0)
	var fade_in = current_command.parameters.get("fade_in", 0.0)


# Command Change Save Access (Code 113), button_id = 89
# Code 113 parameters { selected }
func _command_0113() -> void:
	debug_print("Command 113 is not implemented")

	var selected = current_command.parameters.get("selected", false)


# Command Change Menu Access (Code 114), button_id = 90
# Code 114 parameters { selected }
func _command_0114() -> void:
	debug_print("Command 114 is not implemented")

	var selected = current_command.parameters.get("selected", false)


# Command Change Encounter Rate (Code 115), button_id = 91
# Code 115 parameters { value }
func _command_0115() -> void:
	debug_print("Command 115 is not implemented")

	var value = current_command.parameters.get("value", 0)


# Command Change Formation Access (Code 116), button_id = 92
# Code 116 parameters { selected }
func _command_0116() -> void:
	debug_print("Command 116 is not implemented")

	var selected = current_command.parameters.get("selected", false)


# Command Change Game Speed (Code 117), button_id = 93
# Code 117 parameters { value }
func _command_0117() -> void:
	debug_print("Command 117 is not implemented")

	var value = current_command.parameters.get("value", 0)


# Command Change Actor Scene (Code 118), button_id = 94
# Code 118 parameters { index, path }
func _command_0118() -> void:
	debug_print("Command 118 is not implemented")

	var index = current_command.parameters.get("index", 0)
	var path = current_command.parameters.get("path", "")
	


# Command Change Vehicle Scene (Code 119), button_id = 95
# Code 119 parameters { index, path }
func _command_0119() -> void:
	debug_print("Command 119 is not implemented")

	var index = current_command.parameters.get("index", 0)
	var path = current_command.parameters.get("path", "")


# Command Change Language (Code 120), button_id = 112
# Code 120 parameters { locale }
func _command_0120() -> void:
	debug_print("Command 120 is not implemented")

	var locale = current_command.parameters.get("locale", "en")
	

# Command Change Formation Access (Code 210), button_id = 122
# Code 210 parameters { selected }
func _command_0210() -> void:
	debug_print("Command 210 is not implemented")

	var selected = current_command.parameters.get("selected", false)


# Command Change Formation Access (Code 211), button_ids = 123
# Code 211 parameters { selected }
func _command_0211() -> void:
	debug_print("Command 211 is not implemented")

	var selected = current_command.parameters.get("selected", false)
