@tool
class_name RPGUserParameter
extends  Resource


@export var name: String = ""
@export var default_value: int = 0


func clone(value: bool) -> RPGUserParameter:
	return duplicate(value)
