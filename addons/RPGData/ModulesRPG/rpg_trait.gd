@tool
class_name RPGTrait
extends Resource

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGTrait"

## Code of the trait.
@export var code: int = -1

## Data ID of the trait.
@export var data_id: int = 0

## Value of the trait.
@export var value: int = 0

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}

## Clones the trait.
## @param value bool - Whether to perform a deep clone.
## @return RPGTrait - The cloned trait.
func clone(value: bool = true) -> RPGTrait:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy

## Returns a string representation of the trait.
## @return String - The string representation.
func _to_string() -> String:
	return "<RPGTrait code=%s, data_id=%s, value=%s>" % [code, data_id, value]
