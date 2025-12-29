@tool
class_name VariableTextValue
extends  Resource


func get_class(): return "VariableTextValue"


@export var name: String = ""
@export var value: String = ""


func clone(value: bool = true) -> VariableTextValue:
	return(duplicate(value))
