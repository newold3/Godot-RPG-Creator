@tool
class_name RPGAnimationShake
extends Resource

## Adds vibration effects to animations to give more weight
## and impact to actions.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGAnimationShake"

## Frame at which the shake occurs.
@export var frame: int = 0

## Amplitude of the shake.
@export var amplitude: float = 1.1

## Frequency of the shake.
@export var frequency: float = 10

## Duration of the shake.
@export var duration: float = 0.3

## Target of the shake.
@export var target: int = 0

## Clones the shake.
## @param value bool - Whether to perform a deep clone.
## @return RPGAnimationShake - The cloned shake.
func clone(value: bool = true) -> RPGAnimationShake:
	return duplicate(value)
