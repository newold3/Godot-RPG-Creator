@tool
class_name RPGComponent
extends Resource

## Simple system to identify and relate game elements to each other.
## Useful for creating dependencies between objects.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGComponent"

## Data ID of the component (0 = items, 1 = weapons, 2 = armors, 3 = sets / costumes).
@export var data_id: int = 0

## Item ID of the component.
@export var item_id: int = 1


func get_item() -> Variant:
	var current_item: Variant = null
	var key: String
	
	match data_id:
		0: key = "items"
		1: key = "weapons"
		2: key = "armors"
		_: key = "costumes"
		
	var uid = RPGSYSTEM.id_to_uid(key, item_id)
	current_item = RPGSYSTEM.get_data(key, uid)
	
	return current_item


func _to_string() -> String:
	return "<RPGComponent data_id=%s, item_id=%s>" % [data_id, item_id]


## Clones the component.
## @param value bool - Whether to perform a deep clone.
## @return RPGComponent - The cloned component.
func clone(value: bool = true) -> RPGComponent:
	return duplicate(value)
