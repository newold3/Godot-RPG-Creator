@tool
class_name RPGLearnableSkill
extends  Resource


func get_class(): return "RPGLearnableSkill"


@export var level: int = 0
@export var skill_id: int = 0
@export var notes: String = ""


func clone(value: bool = true) -> RPGLearnableSkill:
	return(duplicate(value))
