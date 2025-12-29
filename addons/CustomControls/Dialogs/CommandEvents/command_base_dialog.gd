@tool
class_name CommandBaseDialog
extends Window


var parameters: Array[RPGEventCommand]
var parameter_code: int = -1


signal command_changed(commands: Array[RPGEventCommand])


func _ready() -> void:
	if not unresizable:
		var key = "config - " + str(ResourceLoader.get_resource_uid(get_scene_file_path()))
		if not "dialog_config" in FileCache.options:
			FileCache.options.dialog_config = {}
		call_deferred("_update_size_and_position", FileCache.options.dialog_config.get(key, {}))
		tree_exiting.connect(func(): FileCache.options.dialog_config[key] = {"size": size, "position": position})
	close_requested.connect(queue_free)


func _update_size_and_position(config: Dictionary) -> void:
	if "size" in config: size = config.size
	#if "position" in config: position = config.position


func set_parameters(_parameters: Array[RPGEventCommand]) -> void:
	parameters = _parameters
	set_data()


func set_data() -> void:
	pass


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	var commands: Array[RPGEventCommand] = build_command_list()
	command_changed.emit(commands)
	queue_free()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	var command = RPGEventCommand.new()
	command.code = parameter_code
	command.indent = parameters[0].indent
	commands.append(command)
	return commands


func _on_cancel_button_pressed() -> void:
	queue_free()
