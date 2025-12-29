@tool
class_name RPGEventCommand
extends Resource


func get_class(): return "RPGEventCommand"


@export var code: int = 0
@export var indent: int = 0
@export var parameters: Dictionary = {}
@export var is_expanded: bool = true
@export var ignore_command: bool = false


func _init(_code: int = 0, _indent: int = 0, _parameters: Dictionary = {}) -> void:
	code = _code
	indent = _indent
	parameters = _parameters


func _to_string() -> String:
	var result = "<RPGEventCommand> code=%s indent=%s parameters=%s" % [code, indent, parameters]
	return result


func clone(value: bool = true) -> RPGEventCommand:
	var new_event_command = duplicate(value)
	
	new_event_command.parameters = parameters.duplicate(value)
	
	return new_event_command
