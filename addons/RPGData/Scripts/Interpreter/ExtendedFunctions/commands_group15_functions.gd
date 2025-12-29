class_name CommandsGroup15
extends CommandHandlerBase


# Command Change Map Name Display (Code 103), button_id = 82
# Code 103 parameters { selected }
func _command_0103() -> void:
	debug_print("Command 103 is not implemented")

	var selected = current_command.parameters.get("selected", false)


# Command Change Battle Back (Code 104), button_id = 83
# Code 104 parameters { path }
func _command_0104() -> void:
	debug_print("Command 104 is not implemented")

	var path = current_command.parameters.get("path", "")


# Command Change Battle Parallax (Code 105), button_id = 84
# Code 105 parameters { path }
func _command_0105() -> void:
	debug_print("Command 105 is not implemented")

	var path = current_command.parameters.get("path", "")


# Command Get Location Info (Code 106), button_id = 85
# Code 106 parameters { variable_type, variable_id, info_selected, location_type, cell }
func _command_0106() -> void:
	debug_print("Command 106 is not implemented")

	var variable_type = current_command.parameters.get("variable_type", 0)
	var variable_id = current_command.parameters.get("variable_id", 0)		
	var info_selected = current_command.parameters.get("info_selected", false)
	var location_type = current_command.parameters.get("location_type", 0)
	var cell = current_command.parameters.get("cell", Vector2i.ZERO)


# Command Change Tileset (Code 107), button_ids = 111
# Code 107 parameters { layer, path }
func _command_0107() -> void:
	debug_print("Command 107 is not implemented")

	var layer = current_command.parameters.get("layer", 0)
	var path = current_command.parameters.get("path", "")



# Command Tile State (Code 125), button_ids = 132
# Code 125 parameters { layer, use_all_layers, state, tiles }
func _command_0125() -> void:
	debug_print("Command 125 is not implemented")

	var layer = current_command.parameters.get("layer", 0)
	var use_all_layers = current_command.parameters.get("use_all_layers", false)
	var state = current_command.parameters.get("state", false)
	var tiles = current_command.parameters.get("tiles", [])
