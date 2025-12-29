@tool
class_name TestCommandEvent
extends Resource

@export var commands: Array[RPGEventCommand]


func _to_string() -> String:
	return "<TestCommandEvent: " + str(commands) + ">"
