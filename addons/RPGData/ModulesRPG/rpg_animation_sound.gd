@tool
class_name RPGAnimationSound
extends Resource

## Controls sound effects in animations, enhancing the
## audiovisual experience.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGAnimationSound"

## Frame at which the sound occurs.
@export var frame: int = 0

## Filename of the sound.
@export var filename: String = ""

## Volume of the sound in decibels.
@export var volume_db: float = 0.0

## Minimum pitch of the sound.
@export var pitch_min: float = 1.0

## Maximum pitch of the sound.
@export var pitch_max: float = 1.0

## Clones the sound.
## @param value bool - Whether to perform a deep clone.
## @return RPGAnimationSound - The cloned sound.
func clone(value: bool = true) -> RPGAnimationSound:
	return duplicate(value)


func _to_string() -> String:
	return "<RPGAnimationSound file=%s frame=%s volume=%s pitch=[%s/%s]>" % [
		filename,
		frame,
		volume_db,
		pitch_min,
		pitch_max
	]
