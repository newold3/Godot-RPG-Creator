@tool
class_name VariableValue
extends  Resource


func get_class(): return "VariableValue"


@export var name: String = ""
@export var value: int = 0


func clone(value: bool = true) -> VariableValue:
	return(duplicate(value))
