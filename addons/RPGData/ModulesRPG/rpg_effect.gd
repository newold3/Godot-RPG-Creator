@tool
class_name RPGEffect
extends  Resource


func get_class(): return "RPGEffect"


@export var code: int = -1
@export var data_id: int = 0
@export var value1: int = 0
@export var value2: int = 0
@export var value3: int = 0

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clone(value: bool = true) -> RPGEffect:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy
