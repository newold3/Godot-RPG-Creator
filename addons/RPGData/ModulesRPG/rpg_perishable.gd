@tool
class_name RPGPerishable
extends  Resource


func get_class(): return "RPGPerishable"


@export var is_perishable: int = 0
@export var duration: int = 0
@export var action: int = 0
@export var conversion_item_id: int = 0


func clear() -> void:
	is_perishable = 0
	duration = 0
	action = 0
	conversion_item_id = 0


func is_enabled() -> bool:
	return is_perishable == 1


func clone(value: bool = true) -> RPGPerishable:
	return(duplicate(value))
