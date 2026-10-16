@tool
class_name RPGLearnableSkill
extends  Resource


func get_class(): return "RPGLearnableSkill"


@export var level: int = 0
@export var skill_id: int = 0
@export var notes: String = ""

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clone(value: bool = true) -> RPGLearnableSkill:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy
