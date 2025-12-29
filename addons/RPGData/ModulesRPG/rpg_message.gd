@tool
class_name RPGMessage
extends  Resource


func get_class(): return "RPGMessage"


@export var id: String = ""
@export var message: String = ""


func clone(value: bool = true) -> RPGMessage:
	return(duplicate(value))
