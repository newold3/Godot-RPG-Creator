@tool
class_name RPGInvocation
extends Resource


func get_class(): return "RPGInvocation"


@export var speed: int = 0
@export var success: int = 100
@export var repeat: int = 1
@export var tp_gain: int = 0
@export var hit_type: int = 0
@export var animation: int = 0
@export var sequence: Array[RPGInvocationSequence] = []


func clear() -> void:
	speed = 0
	success = 100
	repeat = 1
	tp_gain = 0
	hit_type = 0
	animation = 0
	sequence.clear()


func clone(value: bool = true) -> RPGInvocation:
	var new_rpg_invocation: RPGInvocation = duplicate(value)
	for i in new_rpg_invocation.sequence.size():
		new_rpg_invocation.sequence[i] = new_rpg_invocation.sequence[i].clone()
	
	return new_rpg_invocation
