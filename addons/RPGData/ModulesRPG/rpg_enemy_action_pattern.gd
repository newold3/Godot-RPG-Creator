@tool
class_name RPGEnemyAction
extends  Resource


func get_class(): return "RPGEnemyAction"


@export var skill_id: int = 1
@export var condition_type: int = 0
@export var condition_param1: int = 0
@export var condition_param2: int = 0
@export var condition_param3: int = 0
@export var rating: int = 5

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clone(value: bool = true) -> RPGEnemyAction:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy
