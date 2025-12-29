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

## Clears all the properties of the damage.
func clear() -> void:
	type = 0
	element_id = 0
	formula = ""
	variance = 0
	critical = false

## Clones the damage.
## @param value bool - Whether to perform a deep clone.
## @return RPGDamage - The cloned damage.
func clone(value: bool = true) -> RPGDamage:
	return duplicate(value)
