@tool
class_name RPGAnimationFlash
extends Resource

## Handles flashes and light effects in animations to add
## more visual impact.

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGAnimationFlash"

## Frame at which the flash occurs.
@export var frame: int = 0

## Duration of the flash.
@export var duration: float = 0.15

## Color of the flash.
@export var color: Color = Color.WHITE

## Target of the flash.
@export var target: int = 0

## Screen blend type of the flash.
@export var screen_blend_type: int = 0

## Clones the flash.
## @param value bool - Whether to perform a deep clone.
## @return RPGAnimationFlash - The cloned flash.
func clone(value: bool = true) -> RPGAnimationFlash:
	return duplicate(value)
