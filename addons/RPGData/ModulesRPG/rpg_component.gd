@tool
class_name RPGComponent
extends Resource

## Simple system to identify and relate game elements to each other.
## Useful for creating dependencies between objects.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGComponent"

## Data ID of the component (0 = items, 1 = weapons, 2 = armors).
@export var data_id: int = 0

## Item ID of the component.
@export var item_id: int = 1

## Clones the component.
## @param value bool - Whether to perform a deep clone.
## @return RPGComponent - The cloned component.
func clone(value: bool = true) -> RPGComponent:
	return duplicate(value)
