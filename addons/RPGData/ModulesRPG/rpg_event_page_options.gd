@tool
class_name RPGEventPageOptions
extends Resource


func get_class(): return "RPGEventPageOptions"


@export var walking_animation: bool = true
@export var idle_animation: bool = true
@export var fixed_direction: bool = false
@export var passable: bool = false


func clone(value: bool = true) -> RPGEventPageOptions:
	return duplicate(value)
