@tool
class_name SwitchValue
extends  Resource


func get_class(): return "SwitchValue"


@export var name: String = ""
@export var value: bool = false


func clone(value: bool = true) -> SwitchValue:
	return(duplicate(value))
