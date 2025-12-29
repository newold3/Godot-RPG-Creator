@tool
class_name RPGAnimation
extends Resource

## Manages game animations, from skill effects to
## important visual events.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGAnimation"

## Unique identifier for the animation.
@export var id: int = 0

## Name of the animation.
@export var name: String = ""

## Display type of the animation.
@export var display_type: int = 0

## Vertical alignment of the animation.
@export var vertical_align: int = 0

## Filename of the animation.
@export var filename: String = ""

## Scale of the animation.
@export var animation_scale: float = 50

## Speed of the animation.
@export var animation_speed: float = 1.0

## Color of the animation.
@export var animation_color: Color = Color.WHITE

## Rotation of the animation.
@export var rotation: Vector3 = Vector3.ZERO

## Offset of the animation.
@export var offset: Vector2 = Vector2.ZERO

## Sounds associated with the animation.
@export var sounds: Array[RPGAnimationSound] = []

## Flashes associated with the animation.
@export var flashes: Array[RPGAnimationFlash] = []

## Shakes associated with the animation.
@export var shakes: Array[RPGAnimationShake] = []

## Additional notes about this common event.
@export var notes: String = ""

## Clears all the properties of the animation.
func clear() -> void:
	for v in ["name", "filename"]:
		set(v, "")
	for v in [sounds, flashes, shakes]:
		v.clear()
	display_type = 0
	vertical_align = 0
	animation_scale = 50
	animation_speed = 1.0
	animation_color = Color.WHITE
	rotation = Vector3.ZERO
	offset = Vector2.ZERO

## Clones the animation and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGAnimation - The cloned animation.
func clone(value: bool = true) -> RPGAnimation:
	var new_animation = duplicate(value)

	for i in new_animation.sounds.size():
		new_animation.sounds[i] = new_animation.sounds[i].clone(value)
	for i in new_animation.flashes.size():
		new_animation.flashes[i] = new_animation.flashes[i].clone(value)

	return new_animation
