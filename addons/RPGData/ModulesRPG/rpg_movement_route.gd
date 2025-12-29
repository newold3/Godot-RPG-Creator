@tool
class_name RPGMovementRoute
extends Resource


func get_class(): return "RPGMovementRoute"


@export var target: int
@export var repeat: bool
@export var skippable: bool
@export var wait: bool
@export var list: Array[RPGMovementCommand]

var is_route_from_interpreter: bool = false

signal finished()


func _init() -> void:
	repeat = false
	skippable = true
	wait = false
	list = []


func clone(value: bool = true) -> RPGMovementRoute:
	var new_route = duplicate(value)
	
	for i in new_route.list.size():
		new_route.list[i] = new_route.list[i].clone(value)
	
	return new_route
