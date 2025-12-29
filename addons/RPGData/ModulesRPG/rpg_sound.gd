@tool
class_name RPGSound
extends Resource

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGSound"

## Filename of the sound.
@export var filename: String = ""

## Volume of the sound in decibels.
@export var volume_db: float = 0.0

## Pitch scale of the sound.
@export var pitch_scale: float = 1.0

## Random pitch scale of the sound.
@export var random_pitch_scale: float = 1.0

## Initializes the sound with the given parameters.
## @param _filename String - The filename of the sound.
## @param _volume_db float - The volume of the sound in decibels.
## @param _pitch_scale float - The pitch scale of the sound.
## @param _random_pitch_scale float - The random pitch scale of the sound.
func _init(_filename: String = "", _volume_db: float = 0.0, _pitch_scale: float = 1.0, _random_pitch_scale: float = 1.0) -> void:
	filename = _filename
	volume_db = _volume_db
	pitch_scale = _pitch_scale
	random_pitch_scale = _random_pitch_scale

## Clones the sound.
## @param value bool - Whether to perform a deep clone.
## @return RPGSound - The cloned sound.
func clone(value: bool = true) -> RPGSound:
	return duplicate(value)
