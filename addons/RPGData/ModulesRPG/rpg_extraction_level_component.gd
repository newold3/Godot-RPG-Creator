@tool
class_name RPGExtractionLevelComponent
extends  Resource

## category assigned to this level
@export var name: String = ""

## Maximum sub-levels in this profession rank.
@export var max_levels: int = 1

## Base experience required to master this level. Once mastered,
## the character’s level in this profession will increase to the next level
## on the list, if available and if the profession is set to auto level up.
## If it is not, the profession level must be manually changed
## using a command in an event.
## All levels included within this level’s range will require
## this base experience +10% per level starting from the initial one.
@export var experience_to_complete: int = 100


func _init(p_name: String = "", p_experience_to_complete: int = 100) -> void:
	name = p_name
	experience_to_complete = p_experience_to_complete


func clone(value: bool) -> RPGExtractionLevelComponent:
	return duplicate(value)


func _to_string() -> String:
	return "<RPGExtractionLevelComponent name=%s, masterize=%s>" % [name, experience_to_complete]
