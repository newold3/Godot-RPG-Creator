@tool
class_name RPGMovementCommand
extends Resource


func get_class(): return "RPGMovementCommand"


@export var code: int
@export var parameters: Array


func _init(_code: int = 0, _parameters: Array = []) -> void:
	code = _code
	parameters = _parameters


func clone(value: bool = true) -> RPGMovementCommand:
	return(duplicate(value))


func _to_string() -> String:
	return "<RPGMovementCommand %s: code: %s, parameters: %s>" % [get_instance_id(), code, parameters]
