@tool
class_name RPGScope
extends Resource


func get_class(): return "RPGScope"


@export var faction: int
@export var number: int
@export var random: int = 0
@export var status: int


func _init(_faction = 0, _number = 0, _status = 0) -> void:
	faction = _faction
	number = _number
	status = _status


func clear() -> void:
	faction = 0
	number = 0
	random = 0
	status = 0


func clone(value: bool = true) -> RPGScope:
	return(duplicate(value))
