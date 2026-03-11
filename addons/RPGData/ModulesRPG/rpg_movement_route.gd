@tool
class_name RPGMovementRoute
extends Resource


func get_class(): return "RPGMovementRoute"


@export var target: int = -1
@export var repeat: bool = false
@export var skippable: bool = false
@export var wait: bool = false
@export var list: Array[RPGMovementCommand] = []

var is_route_from_interpreter: bool = false

signal finished()


func clone(value: bool = true) -> RPGMovementRoute:
	var new_route = duplicate(value)
	
	for i in new_route.list.size():
		new_route.list[i] = new_route.list[i].clone(value)
	
	return new_route
