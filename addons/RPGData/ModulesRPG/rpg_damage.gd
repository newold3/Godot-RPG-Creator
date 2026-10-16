@tool
class_name RPGDamage
extends Resource

## Handles everything related to combat damage: type, element,
## calculation formulas and criticals. The core of the combat system.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGDamage"

## Type of damage.
@export var type: int = 0

## Element ID of the damage.
@export var element_id: int = 0

## Formula for calculating the damage.
@export var formula: String = ""

## Variance of the damage.
@export var variance: int = 0

## Whether the damage is critical.
@export var critical: bool = false

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}

## Clears all the properties of the damage.
func clear() -> void:
	type = 0
	element_id = 0
	formula = ""
	variance = 0
	critical = false
	if custom_data != null:
		custom_data.clear()
	else:
		custom_data = {}

## Clones the damage.
## @param value bool - Whether to perform a deep clone.
## @return RPGDamage - The cloned damage.
func clone(value: bool = true) -> RPGDamage:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy
