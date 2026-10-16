@tool
class_name RPGPerishable
extends  Resource


func get_class(): return "RPGPerishable"


@export var is_perishable: int = 0
@export var duration: int = 0
@export var action: int = 0
@export var conversion_item_id: int = 0

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clear() -> void:
	is_perishable = 0
	duration = 0
	action = 0
	conversion_item_id = 0
	if custom_data != null:
		custom_data.clear()
	else:
		custom_data = {}


func is_enabled() -> bool:
	return is_perishable == 1


func clone(value: bool = true) -> RPGPerishable:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy
