@tool
class_name RPGTroopCondition
extends  Resource


func get_class(): return "RPGTroopCondition"


@export var turn_ending: bool = false
@export var turn_valid: bool = false
@export var enemy_valid: bool = false
@export var actor_valid: bool = false
@export var switch_valid: bool = false
@export var variable_valid: bool = false
@export var signal_valid: bool = false
@export var turn_a: int = 0
@export var turn_b: int = 0
@export var enemy_id: int = 1
@export var enemy_param_index: int = 0
@export var enemy_param_value: int = 50
@export var enemy_param_operation: int = 0
@export var enemy_param_value_is_percent: bool = true
@export var actor_id: int = 1
@export var actor_param_index: int = 0
@export var actor_param_value: int = 50
@export var actor_param_operation: int = 0
@export var actor_param_value_is_percent: bool = true
@export var switch_id: int = 1
@export var switch_value: bool = true
@export var variable_id: int = 1
@export var variable_operation: int = 0
@export var variable_value: int = 0
@export var span: int = 1
@export var signal_id: int = 0


func clone(value: bool = true) -> RPGTroopCondition:
	return(duplicate(value))
