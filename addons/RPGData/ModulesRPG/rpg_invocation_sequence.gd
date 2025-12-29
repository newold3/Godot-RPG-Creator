@tool
class_name RPGInvocationSequence
extends Resource


func get_class(): return "RPGInvocationSequence"


@export var type: int = 0
@export var parameters: Dictionary = {}


func clone(value: bool = true) -> RPGInvocationSequence:
	return(duplicate(value))


func _to_string() -> String:
	return "<RPGInvocationSequence type=%s parameters=%s>" % [type, parameters]
