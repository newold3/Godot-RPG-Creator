@tool
class_name RPGEventPageCondition
extends Resource


func get_class(): return "RPGEventPageCondition"


@export var use_switch1: bool = false
@export var use_switch2: bool = false
@export var use_local_switch: bool = false
@export var use_variable: bool = false
@export var use_item: bool = false
@export var use_actor: bool = false
@export var switch1_id: int = 1
@export var switch2_id: int = 1
@export var local_switch_id: int = 0
@export var variable_id: int = 1
@export var variable_value: int = 1
@export var variable_operator: int = 4
@export var item_type: int = 0
@export var item_id: int = 1
@export var actor_id: int = 1


func clone(value: bool = true) -> RPGEventPageCondition:
	return(duplicate(value))
