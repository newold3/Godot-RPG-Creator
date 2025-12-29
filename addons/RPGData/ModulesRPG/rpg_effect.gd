@tool
class_name RPGEffect
extends  Resource


func get_class(): return "RPGEffect"


@export var code: int = -1
@export var data_id: int = 0
@export var value1: int = 0
@export var value2: int = 0


func clone(value: bool = true) -> RPGEffect:
	return(duplicate(value))
