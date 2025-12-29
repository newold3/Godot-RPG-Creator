@tool
class_name RPGCurveParams
extends Resource

## Defines progression curves for different game aspects like experience, 
## stats or skills. Essential for balancing character growth.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGCurveParams"

## Name of the curve parameters.
@export var name: String = ""

## Background color of the curve parameters.
@export var background_color: Color = Color.DEEP_SKY_BLUE

## Minimum value of the curve parameters.
@export var min_value: int = 1

## Maximum value of the curve parameters.
@export var max_value: int = 9999

## Data points of the curve parameters.
@export var data: PackedInt32Array = []

## Clones the curve parameters.
## @param value bool - Whether to perform a deep clone.
## @return RPGCurveParams - The cloned curve parameters.
func clone(value: bool = true) -> RPGCurveParams:
	return duplicate(value)
